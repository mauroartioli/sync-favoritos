#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Sync Favoritos - macOS Exporter & Local HTTP Server
Author: Antigravity AI
Description: Parses Safari Bookmarks.plist, exports it to cloud JSON, and
             runs a lightweight HTTP server to feed the Microsoft Edge Sync Extension,
             coupled with a background file watcher thread for iCloud Drive export.
"""

import os
import sys
import json
import shutil
import plistlib
import time
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

GLOBAL_PLIST_PATH = None

def parse_node(node):
    """
    Recursively parses Safari bookmark items.
    """
    node_type = node.get("WebBookmarkType")
    
    if node_type == "WebBookmarkTypeList":
        folder_name = node.get("Title")
        if not folder_name:
            return None
        
        children = []
        for child in node.get("Children", []):
            parsed_child = parse_node(child)
            if parsed_child:
                children.append(parsed_child)
                
        return {
            "type": "folder",
            "name": folder_name,
            "children": children
        }
        
    elif node_type == "WebBookmarkTypeLeaf":
        url = node.get("URLString")
        if not url:
            return None
            
        title = node.get("URIDictionary", {}).get("title")
        if not title:
            title = node.get("Title")
        if not title:
            title = url
            
        return {
            "type": "url",
            "name": title,
            "url": url
        }
        
    return None

def parse_safari_plist(safari_path):
    """
    Reads and parses Safari's plist into a simplified structure.
    """
    if not os.path.exists(safari_path):
        raise FileNotFoundError(f"Safari Bookmarks file not found at '{safari_path}'")
        
    with open(safari_path, "rb") as f:
        plist = plistlib.load(f)
        
    bookmark_bar_items = []
    other_items = []
    
    for child in plist.get("Children", []):
        title = child.get("Title")
        if title == "BookmarksBar":
            for item in child.get("Children", []):
                parsed = parse_node(item)
                if parsed:
                    bookmark_bar_items.append(parsed)
        elif title == "BookmarksMenu":
            for item in child.get("Children", []):
                parsed = parse_node(item)
                if parsed:
                    other_items.append(parsed)
                    
    return {
        "bookmark_bar": bookmark_bar_items,
        "other": other_items
    }

def convert_to_chromium_tree(safari_data):
    """
    Translates simple Safari bookmark JSON structure into Chromium (Edge) Bookmark JSON format.
    """
    next_id = [1]
    fixed_date = "13329000000000000"
    
    def convert_node(node):
        node_id = str(next_id[0])
        next_id[0] += 1
        
        if node["type"] == "folder":
            children = []
            for child in node.get("children", []):
                children.append(convert_node(child))
            return {
                "date_added": fixed_date,
                "id": node_id,
                "name": node["name"],
                "type": "folder",
                "children": children
            }
        else:
            return {
                "date_added": fixed_date,
                "id": node_id,
                "name": node["name"],
                "type": "url",
                "url": node["url"]
            }
            
    bar_children = [convert_node(item) for item in safari_data.get("bookmark_bar", [])]
    other_children = [convert_node(item) for item in safari_data.get("other", [])]
    
    tree = {
        "roots": {
            "bookmark_bar": {
                "children": bar_children,
                "date_added": fixed_date,
                "date_modified": fixed_date,
                "id": "0",
                "name": "Barra de favoritos",
                "type": "folder"
            },
            "other": {
                "children": other_children,
                "date_added": fixed_date,
                "date_modified": fixed_date,
                "id": "0",
                "name": "Outros favoritos",
                "type": "folder"
            },
            "synced": {
                "children": [],
                "date_added": fixed_date,
                "date_modified": fixed_date,
                "id": "0",
                "name": "Favoritos móveis",
                "type": "folder"
            }
        },
        "version": 1
    }
    total_nodes = next_id[0] - 1
    return tree, total_nodes

class SafariBookmarksServer(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass # Silenciar logs de requisição no terminal

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        if self.path in ('/', '/safari_bookmarks.json'):
            try:
                # Análise dinâmica a cada requisição garante sincronismo perfeito em tempo real!
                safari_data = parse_safari_plist(GLOBAL_PLIST_PATH)
                response_bytes = json.dumps(safari_data, ensure_ascii=False, indent=2).encode('utf-8')
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(response_bytes)
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                error_response = json.dumps({"error": str(e)}).encode('utf-8')
                self.wfile.write(error_response)
        else:
            self.send_response(404)
            self.end_headers()

def watch_safari_plist(safari_path, export_path, local_edge_path):
    print("Iniciando monitoramento do arquivo Bookmarks.plist do Safari...")
    last_mtime = 0
    if os.path.exists(safari_path):
        last_mtime = os.path.getmtime(safari_path)
        
    while True:
        time.sleep(5)
        try:
            if os.path.exists(safari_path):
                current_mtime = os.path.getmtime(safari_path)
                if current_mtime != last_mtime:
                    last_mtime = current_mtime
                    print(f"Alteração detectada no Safari Bookmarks.plist! Re-exportando...")
                    
                    exported_data = parse_safari_plist(safari_path)
                    
                    # 1. Exporta JSON para nuvem
                    export_dir = os.path.dirname(export_path)
                    if export_dir and not os.path.exists(export_dir):
                        os.makedirs(export_dir, exist_ok=True)
                        
                    with open(export_path, "w", encoding="utf-8") as f:
                        json.dump(exported_data, f, ensure_ascii=False, indent=2)
                    print(f"✓ Re-exportação concluída com sucesso em '{export_path}'")
                    
                    # 2. Local Mac Edge direct overwrite (Fallback backup)
                    if local_edge_path:
                        local_edge_path_expanded = os.path.expanduser(local_edge_path)
                        chromium_tree, total_nodes = convert_to_chromium_tree(exported_data)
                        
                        if os.path.exists(local_edge_path_expanded):
                            shutil.copy2(local_edge_path_expanded, f"{local_edge_path_expanded}.bak")
                            
                        with open(local_edge_path_expanded, "w", encoding="utf-8") as f:
                            json.dump(chromium_tree, f, ensure_ascii=False, indent=2)
                        print(f"✓ Sincronismo local de backup com Edge Mac concluído ({total_nodes} nós)")
        except Exception as e:
            print(f"Erro na thread de monitoramento: {e}", file=sys.stderr)

def run_server(plist_path, export_path, local_edge_path, port=5003):
    global GLOBAL_PLIST_PATH
    GLOBAL_PLIST_PATH = plist_path
    
    # Executa uma exportação inicial imediata para alinhar nuvem e fallback local
    try:
        print("Executando alinhamento inicial de exportação...")
        exported_data = parse_safari_plist(plist_path)
        
        # Cloud export
        export_dir = os.path.dirname(export_path)
        if export_dir and not os.path.exists(export_dir):
            os.makedirs(export_dir, exist_ok=True)
        with open(export_path, "w", encoding="utf-8") as f:
            json.dump(exported_data, f, ensure_ascii=False, indent=2)
            
        # Local fallback Edge export
        if local_edge_path:
            local_edge_path_expanded = os.path.expanduser(local_edge_path)
            chromium_tree, _ = convert_to_chromium_tree(exported_data)
            with open(local_edge_path_expanded, "w", encoding="utf-8") as f:
                json.dump(chromium_tree, f, ensure_ascii=False, indent=2)
        print("✓ Exportação e alinhamento inicial concluídos.")
    except Exception as e:
        print(f"Aviso no alinhamento inicial: {e}")
        
    # Inicializa a thread de monitoramento em segundo plano (daemon)
    watcher_thread = threading.Thread(
        target=watch_safari_plist, 
        args=(plist_path, export_path, local_edge_path), 
        daemon=True
    )
    watcher_thread.start()
    
    server_address = ('localhost', port)
    httpd = HTTPServer(server_address, SafariBookmarksServer)
    print(f"Servidor iniciado em http://localhost:{port} (servindo favoritos em tempo real)")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nDesligando servidor...")
        httpd.server_close()

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, "..", "config.json")
    if not os.path.exists(config_path):
        config_path = os.path.join(script_dir, "config.json")
        
    if not os.path.exists(config_path):
        print(f"Erro: Arquivo de configuração não encontrado em {config_path}", file=sys.stderr)
        sys.exit(1)
        
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            config = json.load(f)
    except Exception as e:
        print(f"Erro: Falha ao analisar config.json: {e}", file=sys.stderr)
        sys.exit(1)
        
    safari_path = os.path.expanduser(config.get("safari_bookmarks_path", "~/Library/Safari/Bookmarks.plist"))
    export_path = os.path.expanduser(config.get("export_json_path", "~/Library/Mobile Documents/com~apple~CloudDocs/safari_bookmarks.json"))
    local_edge_path = config.get("local_edge_bookmarks_path_mac")
    
    # Se rodar com o argumento --server ou -s, ativa o servidor HTTP local com o watcher acoplado
    if len(sys.argv) > 1 and sys.argv[1] in ('--server', '-s'):
        run_server(safari_path, export_path, local_edge_path, port=5003)
        return

    print(f"Lendo favoritos do Safari em: {safari_path}")
    
    try:
        exported_data = parse_safari_plist(safari_path)
    except Exception as e:
        print(f"Erro: {e}", file=sys.stderr)
        sys.exit(1)
        
    # 1. Exporta JSON para o iCloud Drive / OneDrive (Sincronismo com Windows)
    export_dir = os.path.dirname(export_path)
    if export_dir and not os.path.exists(export_dir):
        try:
            os.makedirs(export_dir, exist_ok=True)
        except Exception as e:
            print(f"Aviso: Falha ao criar diretório de exportação {export_dir}: {e}")
            
    try:
        with open(export_path, "w", encoding="utf-8") as f:
            json.dump(exported_data, f, ensure_ascii=False, indent=2)
        print(f"Sucesso: Favoritos do Safari exportados para a nuvem em '{export_path}'")
    except Exception as e:
        print(f"Erro: Falha ao gravar JSON na nuvem '{export_path}': {e}", file=sys.stderr)
        
    # 2. Grava favoritos diretamente no arquivo local do Edge (Backup/Sincronismo alternativo)
    if local_edge_path:
        local_edge_path = os.path.expanduser(local_edge_path)
        print(f"Caminho do Edge local (backup fallback) configurado em: {local_edge_path}")
        
        local_edge_dir = os.path.dirname(local_edge_path)
        if not os.path.exists(local_edge_dir):
            try:
                os.makedirs(local_edge_dir, exist_ok=True)
            except Exception as e:
                print(f"Erro: Falha ao criar diretório do perfil local do Edge {local_edge_dir}: {e}", file=sys.stderr)
                sys.exit(1)
                
        chromium_tree, total_nodes = convert_to_chromium_tree(exported_data)
        
        if os.path.exists(local_edge_path):
            backup_path = f"{local_edge_path}.bak"
            try:
                shutil.copy2(local_edge_path, backup_path)
                print(f"✓ Backup criado dos favoritos locais do Edge em: {backup_path}")
            except Exception as e:
                print(f"Aviso: Falha ao criar backup dos favoritos locais do Edge: {e}")
                
        try:
            with open(local_edge_path, "w", encoding="utf-8") as f:
                json.dump(chromium_tree, f, ensure_ascii=False, indent=2)
            print(f"✓ SUCESSO: Favoritos do Safari sincronizados diretamente com o Edge local no Mac (Fallback)!")
            print(f"  Total de {total_nodes} favoritos/pastas espelhados localmente.")
        except Exception as e:
            print(f"Erro: Falha ao gravar favoritos locais do Edge: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
