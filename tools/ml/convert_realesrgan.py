#!/usr/bin/env python3
#
# 概要:
# このスクリプトは `realesr-general-x4v3` の PyTorch チェックポイントを
# Core ML の `.mlpackage` / `.mlmodelc` へ変換するための補助ツールです。
# GLogo の AI 高画質化機能で利用するモデルを、アプリ組み込み可能な形式へ変換します。
#

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CHECKPOINT = REPO_ROOT / "tools/ml/checkpoints/realesr-general-x4v3.pth"
DEFAULT_ARTIFACT_DIR = REPO_ROOT / "tools/ml/artifacts"
DEFAULT_MLPACKAGE = DEFAULT_ARTIFACT_DIR / "realesr-general-x4v3.mlpackage"
DEFAULT_COMPILED_OUTPUT_DIR = REPO_ROOT / "GLogo/Resources/MLModels"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="realesr-general-x4v3 を Core ML へ変換します。"
    )
    parser.add_argument(
        "--checkpoint",
        type=Path,
        default=DEFAULT_CHECKPOINT,
        help="PyTorch チェックポイント (.pth) のパス",
    )
    parser.add_argument(
        "--mlpackage-output",
        type=Path,
        default=DEFAULT_MLPACKAGE,
        help="生成する .mlpackage の出力先",
    )
    parser.add_argument(
        "--compiled-output-dir",
        type=Path,
        default=DEFAULT_COMPILED_OUTPUT_DIR,
        help="生成する .mlmodelc の配置先ディレクトリ",
    )
    parser.add_argument(
        "--input-size",
        type=int,
        default=256,
        help="固定入力サイズ。タイル変換前提なので 256 を推奨します。",
    )
    parser.add_argument(
        "--minimum-ios-version",
        type=int,
        default=17,
        help="Core ML 変換時の最小 iOS バージョン",
    )
    parser.add_argument(
        "--skip-compile",
        action="store_true",
        help=".mlpackage のみ生成して .mlmodelc コンパイルを省略します。",
    )
    return parser.parse_args()


def load_dependencies():
    try:
        import coremltools as ct
        import torch
    except ImportError as error:
        raise SystemExit(
            "必要な Python 依存が足りません。"
            " `pip install -r tools/ml/requirements.txt` を実行してください。"
        ) from error

    return ct, torch


def make_srvgg_arch_class(torch):
    nn = torch.nn
    functional = torch.nn.functional

    def make_activation(num_feat: int, act_type: str):
        if act_type == "relu":
            return nn.ReLU(inplace=True)
        if act_type == "prelu":
            return nn.PReLU(num_parameters=num_feat)
        if act_type == "leakyrelu":
            return nn.LeakyReLU(negative_slope=0.1, inplace=True)
        raise SystemExit(f"未対応の活性化関数です: {act_type}")

    class SRVGGNetCompact(nn.Module):
        """Real-ESRGAN の `realesr-general-x4v3` で使う超解像ネットワーク。"""

        def __init__(
            self,
            num_in_ch=3,
            num_out_ch=3,
            num_feat=64,
            num_conv=16,
            upscale=4,
            act_type="prelu"
        ):
            super().__init__()
            self.num_in_ch = num_in_ch
            self.num_out_ch = num_out_ch
            self.num_feat = num_feat
            self.num_conv = num_conv
            self.upscale = upscale
            self.act_type = act_type

            self.body = nn.ModuleList()
            self.body.append(nn.Conv2d(num_in_ch, num_feat, 3, 1, 1))
            self.body.append(make_activation(num_feat, act_type))

            for _ in range(num_conv):
                self.body.append(nn.Conv2d(num_feat, num_feat, 3, 1, 1))
                self.body.append(make_activation(num_feat, act_type))

            self.body.append(nn.Conv2d(num_feat, num_out_ch * upscale * upscale, 3, 1, 1))
            self.upsampler = nn.PixelShuffle(upscale)

        def forward(self, x):
            out = x
            for layer in self.body:
                out = layer(out)

            out = self.upsampler(out)
            base = functional.interpolate(x, scale_factor=self.upscale, mode="nearest")
            return out + base

    return SRVGGNetCompact


def build_model(torch, srvgg_arch, checkpoint_path: Path):
    if not checkpoint_path.exists():
        raise SystemExit(f"チェックポイントが見つかりません: {checkpoint_path}")

    model = srvgg_arch(
        num_in_ch=3,
        num_out_ch=3,
        num_feat=64,
        num_conv=32,
        upscale=4,
        act_type="prelu",
    )

    checkpoint = torch.load(checkpoint_path, map_location="cpu")
    if isinstance(checkpoint, dict):
        state_dict = (
            checkpoint.get("params_ema")
            or checkpoint.get("params")
            or checkpoint.get("state_dict")
            or checkpoint
        )
    else:
        state_dict = checkpoint

    normalized_state_dict = {}
    for key, value in state_dict.items():
        normalized_key = key.removeprefix("module.")
        normalized_state_dict[normalized_key] = value

    model.load_state_dict(normalized_state_dict, strict=True)
    model.eval()
    return model


def resolve_minimum_target(ct, ios_version: int):
    candidate_name = f"iOS{ios_version}"
    if not hasattr(ct.target, candidate_name):
        raise SystemExit(f"coremltools が {candidate_name} をサポートしていません。")
    return getattr(ct.target, candidate_name)


def convert_to_coreml(ct, torch, model, input_size: int, mlpackage_output: Path, minimum_ios_version: int):
    mlpackage_output.parent.mkdir(parents=True, exist_ok=True)

    example_input = torch.rand(1, 3, input_size, input_size)
    traced_model = torch.jit.trace(model, example_input)
    traced_model.eval()

    target = resolve_minimum_target(ct, minimum_ios_version)
    image_input = ct.ImageType(
        name="input",
        shape=example_input.shape,
        scale=1 / 255.0,
        bias=[0.0, 0.0, 0.0],
        color_layout=ct.colorlayout.RGB,
    )
    tensor_output = ct.TensorType(name="output")

    mlmodel = ct.convert(
        traced_model,
        convert_to="mlprogram",
        inputs=[image_input],
        outputs=[tensor_output],
        minimum_deployment_target=target,
        compute_precision=ct.precision.FLOAT16,
    )
    mlmodel.save(str(mlpackage_output))


def compile_mlpackage(mlpackage_output: Path, compiled_output_dir: Path) -> Path:
    if shutil.which("xcrun") is None:
        raise SystemExit("`xcrun` が見つかりません。Xcode Command Line Tools を確認してください。")

    compiled_output_dir.mkdir(parents=True, exist_ok=True)
    command = [
        "xcrun",
        "coremlcompiler",
        "compile",
        str(mlpackage_output),
        str(compiled_output_dir),
    ]
    subprocess.run(command, check=True)
    compiled_path = compiled_output_dir / f"{mlpackage_output.stem}.mlmodelc"
    if not compiled_path.exists():
        raise SystemExit(f".mlmodelc の生成に失敗しました: {compiled_path}")
    return compiled_path


def main() -> int:
    args = parse_args()
    ct, torch = load_dependencies()
    srvgg_arch = make_srvgg_arch_class(torch)
    model = build_model(torch, srvgg_arch, args.checkpoint)

    print(f"[1/2] Core ML へ変換: {args.mlpackage_output}")
    convert_to_coreml(
        ct=ct,
        torch=torch,
        model=model,
        input_size=args.input_size,
        mlpackage_output=args.mlpackage_output,
        minimum_ios_version=args.minimum_ios_version,
    )

    if args.skip_compile:
        print("[2/2] .mlmodelc コンパイルはスキップしました。")
        return 0

    print(f"[2/2] .mlmodelc を生成: {args.compiled_output_dir}")
    compiled_path = compile_mlpackage(
        mlpackage_output=args.mlpackage_output,
        compiled_output_dir=args.compiled_output_dir,
    )
    print(f"完了: {compiled_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
