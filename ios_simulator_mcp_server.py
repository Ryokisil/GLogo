#!/usr/bin/env python3
"""
iOS Simulator MCP Server
iOSシミュレーターを制御するためのMCPサーバー（正しいMCPプロトコル実装）
"""

import asyncio
import json
import subprocess
import sys
from typing import Any, Dict, List, Optional

class IOSSimulatorMCPServer:
    def __init__(self):
        self.version = "1.0.0"
        self.request_id = 0
        
    async def handle_jsonrpc_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """JSON-RPCリクエストを処理"""
        method = request.get("method")
        params = request.get("params", {})
        request_id = request.get("id")
        
        try:
            if method == "initialize":
                result = await self.initialize(params)
            elif method == "tools/list":
                result = await self.list_tools()
            elif method == "tools/call":
                result = await self.call_tool(params)
            else:
                return {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {"code": -32601, "message": f"Method not found: {method}"}
                }
            
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": result
            }
            
        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32603, "message": str(e)}
            }
    
    async def initialize(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """MCPサーバーを初期化"""
        return {
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "tools": {}
            },
            "serverInfo": {
                "name": "ios-simulator-mcp",
                "version": self.version
            }
        }
    
    async def list_tools(self) -> Dict[str, Any]:
        """利用可能なツールのリストを返す"""
        tools = [
            {
                "name": "list_devices",
                "description": "利用可能なiOSシミュレーターデバイスをリストアップ",
                "inputSchema": {
                    "type": "object",
                    "properties": {},
                    "required": []
                }
            },
            {
                "name": "boot_device",
                "description": "指定されたデバイスを起動",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "device_id": {
                            "type": "string",
                            "description": "デバイスのUDIDまたはデバイス名"
                        }
                    },
                    "required": ["device_id"]
                }
            },
            {
                "name": "shutdown_device",
                "description": "指定されたデバイスをシャットダウン",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "device_id": {
                            "type": "string",
                            "description": "デバイスのUDIDまたは'booted'"
                        }
                    },
                    "required": ["device_id"]
                }
            },
            {
                "name": "install_app",
                "description": "アプリをシミュレーターにインストール",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "device_id": {
                            "type": "string",
                            "description": "デバイスのUDIDまたは'booted'"
                        },
                        "app_path": {
                            "type": "string",
                            "description": ".appファイルのパス"
                        }
                    },
                    "required": ["device_id", "app_path"]
                }
            },
            {
                "name": "launch_app",
                "description": "アプリを起動",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "device_id": {
                            "type": "string",
                            "description": "デバイスのUDIDまたは'booted'"
                        },
                        "bundle_id": {
                            "type": "string",
                            "description": "アプリのBundle ID"
                        }
                    },
                    "required": ["device_id", "bundle_id"]
                }
            },
            {
                "name": "build_and_run",
                "description": "Xcodeプロジェクトをビルドしてシミュレーターで実行",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "project_path": {
                            "type": "string",
                            "description": "Xcodeプロジェクトのパス"
                        },
                        "scheme": {
                            "type": "string",
                            "description": "ビルドスキーム"
                        },
                        "device_id": {
                            "type": "string",
                            "description": "デバイスのUDIDまたは'booted'",
                            "default": "booted"
                        }
                    },
                    "required": ["project_path", "scheme"]
                }
            },
            {
                "name": "get_app_status",
                "description": "アプリの実行状態を確認",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "device_id": {
                            "type": "string",
                            "description": "デバイスのUDIDまたは'booted'"
                        },
                        "bundle_id": {
                            "type": "string",
                            "description": "アプリのBundle ID"
                        }
                    },
                    "required": ["device_id", "bundle_id"]
                }
            }
        ]
        
        return {"tools": tools}
    
    async def call_tool(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """ツールを実行"""
        name = params.get("name")
        arguments = params.get("arguments", {})
        
        if name == "list_devices":
            return await self.list_devices()
        elif name == "boot_device":
            return await self.boot_device(arguments["device_id"])
        elif name == "shutdown_device":
            return await self.shutdown_device(arguments["device_id"])
        elif name == "install_app":
            return await self.install_app(arguments["device_id"], arguments["app_path"])
        elif name == "launch_app":
            return await self.launch_app(arguments["device_id"], arguments["bundle_id"])
        elif name == "build_and_run":
            return await self.build_and_run(
                arguments["project_path"], 
                arguments["scheme"],
                arguments.get("device_id", "booted")
            )
        elif name == "get_app_status":
            return await self.get_app_status(arguments["device_id"], arguments["bundle_id"])
        else:
            return {"error": f"Unknown tool: {name}"}
    
    async def run_command(self, args: List[str]) -> Dict[str, Any]:
        """コマンドを実行"""
        try:
            result = subprocess.run(args, capture_output=True, text=True, timeout=30)
            return {
                "success": result.returncode == 0,
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr
            }
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "error": "Command timed out after 30 seconds"
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    async def list_devices(self) -> Dict[str, Any]:
        """デバイスリストを取得"""
        result = await self.run_command(["xcrun", "simctl", "list", "devices", "available", "--json"])
        if result["success"]:
            try:
                devices_data = json.loads(result["stdout"])
                return {
                    "content": [{"type": "text", "text": json.dumps(devices_data, indent=2, ensure_ascii=False)}]
                }
            except json.JSONDecodeError:
                return {
                    "content": [{"type": "text", "text": f"JSON解析エラー: {result['stdout']}"}]
                }
        return {
            "content": [{"type": "text", "text": f"コマンド失敗: {result['stderr']}"}]
        }
    
    async def boot_device(self, device_id: str) -> Dict[str, Any]:
        """デバイスを起動"""
        result = await self.run_command(["xcrun", "simctl", "boot", device_id])
        status = "起動成功" if result["success"] else f"起動失敗: {result['stderr']}"
        return {
            "content": [{"type": "text", "text": status}]
        }
    
    async def shutdown_device(self, device_id: str) -> Dict[str, Any]:
        """デバイスをシャットダウン"""
        result = await self.run_command(["xcrun", "simctl", "shutdown", device_id])
        status = "シャットダウン成功" if result["success"] else f"シャットダウン失敗: {result['stderr']}"
        return {
            "content": [{"type": "text", "text": status}]
        }
    
    async def install_app(self, device_id: str, app_path: str) -> Dict[str, Any]:
        """アプリをインストール"""
        result = await self.run_command(["xcrun", "simctl", "install", device_id, app_path])
        status = "インストール成功" if result["success"] else f"インストール失敗: {result['stderr']}"
        return {
            "content": [{"type": "text", "text": status}]
        }
    
    async def launch_app(self, device_id: str, bundle_id: str) -> Dict[str, Any]:
        """アプリを起動"""
        result = await self.run_command(["xcrun", "simctl", "launch", device_id, bundle_id])
        status = "アプリ起動成功" if result["success"] else f"アプリ起動失敗: {result['stderr']}"
        return {
            "content": [{"type": "text", "text": status}]
        }
    
    async def build_and_run(self, project_path: str, scheme: str, device_id: str = "booted") -> Dict[str, Any]:
        """プロジェクトをビルドしてシミュレーターで実行"""
        # ビルド
        build_result = await self.run_command([
            "xcodebuild",
            "-project", project_path,
            "-scheme", scheme,
            "-destination", "generic/platform=iOS Simulator",
            "build"
        ])
        
        if not build_result["success"]:
            return {
                "content": [{"type": "text", "text": f"ビルド失敗:\n{build_result['stderr']}"}]
            }
        
        # アプリを起動（Bundle IDが必要）
        # 実際の実装では、ビルド結果からBundle IDを取得する必要があります
        return {
            "content": [{"type": "text", "text": f"ビルド成功:\n{build_result['stdout']}"}]
        }
    
    async def get_app_status(self, device_id: str, bundle_id: str) -> Dict[str, Any]:
        """アプリの実行状態を確認"""
        result = await self.run_command(["xcrun", "simctl", "spawn", device_id, "launchctl", "list"])
        if result["success"]:
            status = "実行中" if bundle_id in result["stdout"] else "停止中"
        else:
            status = f"状態確認失敗: {result['stderr']}"
        
        return {
            "content": [{"type": "text", "text": status}]
        }

async def main():
    """メイン関数"""
    server = IOSSimulatorMCPServer()
    
    # 標準入出力でJSON-RPCメッセージを処理
    while True:
        try:
            line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
            if not line:
                break
            
            line = line.strip()
            if not line:
                continue
            
            try:
                request = json.loads(line)
                response = await server.handle_jsonrpc_request(request)
                print(json.dumps(response, ensure_ascii=False))
                sys.stdout.flush()
            except json.JSONDecodeError:
                error_response = {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"code": -32700, "message": "Parse error"}
                }
                print(json.dumps(error_response))
                sys.stdout.flush()
                
        except EOFError:
            break
        except Exception as e:
            error_response = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32603, "message": str(e)}
            }
            print(json.dumps(error_response))
            sys.stdout.flush()

if __name__ == "__main__":
    asyncio.run(main())