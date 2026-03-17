import 'dart:convert';
import 'dart:io';

import 'package:fx_core/fx_core.dart';
import 'package:fx_graph/fx_graph.dart';
import 'package:path/path.dart' as p;

/// Serves an interactive dependency graph visualization on localhost.
class GraphWebServer {
  final Workspace workspace;
  final ProjectGraph graph;

  GraphWebServer({required this.workspace, required this.graph});

  Future<HttpServer> serve({int port = 4211}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

    server.listen((request) async {
      if (request.uri.path == '/api/graph') {
        _serveGraphData(request);
      } else {
        _serveHtml(request);
      }
    });

    return server;
  }

  void _serveGraphData(HttpRequest request) {
    final nodes = workspace.projects
        .map(
          (proj) => {
            'id': proj.name,
            'type': proj.type.toJson(),
            'tags': proj.tags,
            'path': proj.path,
            'folder': p.dirname(
              p.relative(proj.path, from: workspace.rootPath),
            ),
          },
        )
        .toList();

    final edges = <Map<String, String>>[];
    for (final proj in workspace.projects) {
      for (final dep in graph.dependenciesOf(proj.name)) {
        edges.add({'source': proj.name, 'target': dep});
      }
    }

    // Compute folder groups
    final groups = <String, List<String>>{};
    for (final proj in workspace.projects) {
      final folder = p.dirname(p.relative(proj.path, from: workspace.rootPath));
      groups.putIfAbsent(folder, () => []).add(proj.name);
    }
    final groupList = groups.entries
        .map((e) => {'folder': e.key, 'projects': e.value})
        .toList();

    final data = jsonEncode({
      'nodes': nodes,
      'edges': edges,
      'groups': groupList,
    });
    request.response
      ..headers.contentType = ContentType.json
      ..write(data)
      ..close();
  }

  void _serveHtml(HttpRequest request) {
    request.response
      ..headers.contentType = ContentType.html
      ..write(_htmlTemplate)
      ..close();
  }

  static const _htmlTemplate = '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>fx — Project Graph</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         background: #0d1117; color: #c9d1d9; overflow: hidden; }
  #controls { position: fixed; top: 12px; left: 12px; z-index: 10;
              background: #161b22; border: 1px solid #30363d; border-radius: 8px;
              padding: 12px; display: flex; gap: 8px; align-items: center; }
  #controls input { background: #0d1117; border: 1px solid #30363d; color: #c9d1d9;
                    padding: 6px 10px; border-radius: 4px; width: 200px; }
  #info { position: fixed; bottom: 12px; right: 12px; z-index: 10;
          background: #161b22; border: 1px solid #30363d; border-radius: 8px;
          padding: 12px; max-width: 300px; display: none; }
  #info h3 { margin-bottom: 8px; color: #58a6ff; }
  #info p { font-size: 13px; margin: 4px 0; }
  svg { width: 100vw; height: 100vh; }
  .node circle { stroke-width: 2; cursor: pointer; }
  .node text { fill: #c9d1d9; font-size: 12px; pointer-events: none; }
  .link { stroke: #30363d; stroke-width: 1.5; fill: none; marker-end: url(#arrowhead); }
  .link.highlighted { stroke: #58a6ff; stroke-width: 2.5; }
  .node.dimmed circle { opacity: 0.2; }
  .node.dimmed text { opacity: 0.2; }
  .link.dimmed { opacity: 0.1; }
  .group-box { fill: none; stroke: #30363d; stroke-width: 1; stroke-dasharray: 5,3;
               rx: 8; ry: 8; cursor: pointer; }
  .group-box:hover { stroke: #58a6ff; }
  .group-label { fill: #8b949e; font-size: 11px; }
</style>
</head>
<body>
<div id="controls">
  <input id="search" type="text" placeholder="Filter projects..." />
  <span id="count"></span>
</div>
<div id="info">
  <h3 id="infoName"></h3>
  <p id="infoType"></p>
  <p id="infoDeps"></p>
  <p id="infoTags"></p>
</div>
<svg id="graph">
  <defs>
    <marker id="arrowhead" viewBox="0 0 10 10" refX="20" refY="5"
            markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#30363d" />
    </marker>
  </defs>
</svg>
<script>
const typeColors = {
  dart_package: '#58a6ff', flutter_package: '#a371f7',
  flutter_app: '#f778ba', dart_cli: '#3fb950'
};

fetch('/api/graph').then(r => r.json()).then(data => {
  const svg = document.getElementById('graph');
  const w = window.innerWidth, h = window.innerHeight;
  const nodes = data.nodes, edges = data.edges;

  // Simple force layout
  const pos = {};
  const cols = Math.ceil(Math.sqrt(nodes.length));
  nodes.forEach((n, i) => {
    pos[n.id] = {
      x: 150 + (i % cols) * (w - 300) / Math.max(cols - 1, 1),
      y: 100 + Math.floor(i / cols) * 80
    };
  });

  // Simple force-directed iterations
  for (let iter = 0; iter < 100; iter++) {
    nodes.forEach((a, i) => {
      nodes.forEach((b, j) => {
        if (i >= j) return;
        const dx = pos[a.id].x - pos[b.id].x;
        const dy = pos[a.id].y - pos[b.id].y;
        const d = Math.sqrt(dx*dx + dy*dy) || 1;
        const f = 5000 / (d * d);
        pos[a.id].x += dx/d * f;
        pos[a.id].y += dy/d * f;
        pos[b.id].x -= dx/d * f;
        pos[b.id].y -= dy/d * f;
      });
    });
    edges.forEach(e => {
      const dx = pos[e.target].x - pos[e.source].x;
      const dy = pos[e.target].y - pos[e.source].y;
      const d = Math.sqrt(dx*dx + dy*dy) || 1;
      const f = (d - 150) * 0.01;
      pos[e.source].x += dx/d * f;
      pos[e.source].y += dy/d * f;
      pos[e.target].x -= dx/d * f;
      pos[e.target].y -= dy/d * f;
    });
  }

  // Center
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  nodes.forEach(n => {
    minX = Math.min(minX, pos[n.id].x); minY = Math.min(minY, pos[n.id].y);
    maxX = Math.max(maxX, pos[n.id].x); maxY = Math.max(maxY, pos[n.id].y);
  });
  const cx = (maxX + minX) / 2, cy = (maxY + minY) / 2;
  nodes.forEach(n => { pos[n.id].x += w/2 - cx; pos[n.id].y += h/2 - cy; });

  // Draw edges
  const edgeEls = edges.map(e => {
    const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    line.setAttribute('x1', pos[e.source].x); line.setAttribute('y1', pos[e.source].y);
    line.setAttribute('x2', pos[e.target].x); line.setAttribute('y2', pos[e.target].y);
    line.setAttribute('class', 'link');
    line.dataset.source = e.source; line.dataset.target = e.target;
    svg.appendChild(line);
    return line;
  });

  // Draw nodes
  const nodeEls = nodes.map(n => {
    const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    g.setAttribute('class', 'node'); g.dataset.id = n.id;
    g.setAttribute('transform', `translate(\${pos[n.id].x},\${pos[n.id].y})`);

    const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    circle.setAttribute('r', 8);
    circle.setAttribute('fill', typeColors[n.type] || '#58a6ff');
    circle.setAttribute('stroke', '#0d1117');

    const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    text.setAttribute('dx', 14); text.setAttribute('dy', 4);
    text.textContent = n.id;

    g.appendChild(circle); g.appendChild(text);
    svg.appendChild(g);

    g.addEventListener('click', () => {
      document.getElementById('info').style.display = 'block';
      document.getElementById('infoName').textContent = n.id;
      document.getElementById('infoType').textContent = 'Type: ' + n.type;
      document.getElementById('infoDeps').textContent = 'Deps: ' +
        edges.filter(e => e.source === n.id).map(e => e.target).join(', ');
      document.getElementById('infoTags').textContent = n.tags.length ? 'Tags: ' + n.tags.join(', ') : '';

      // Highlight connected
      const connected = new Set([n.id]);
      edges.forEach(e => { if (e.source === n.id || e.target === n.id) { connected.add(e.source); connected.add(e.target); }});
      nodeEls.forEach(el => el.classList.toggle('dimmed', !connected.has(el.dataset.id)));
      edgeEls.forEach(el => {
        el.classList.toggle('dimmed', !connected.has(el.dataset.source) || !connected.has(el.dataset.target));
        el.classList.toggle('highlighted', el.dataset.source === n.id || el.dataset.target === n.id);
      });
    });

    return g;
  });

  // Draw folder groups as composite boxes
  if (data.groups) {
    data.groups.forEach(g => {
      const members = g.projects.map(id => pos[id]).filter(Boolean);
      if (members.length < 2) return;
      const pad = 30;
      let gMinX = Infinity, gMinY = Infinity, gMaxX = -Infinity, gMaxY = -Infinity;
      members.forEach(p => {
        gMinX = Math.min(gMinX, p.x); gMinY = Math.min(gMinY, p.y);
        gMaxX = Math.max(gMaxX, p.x); gMaxY = Math.max(gMaxY, p.y);
      });
      const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
      rect.setAttribute('x', gMinX - pad); rect.setAttribute('y', gMinY - pad);
      rect.setAttribute('width', gMaxX - gMinX + pad*2);
      rect.setAttribute('height', gMaxY - gMinY + pad*2);
      rect.setAttribute('class', 'group-box');
      svg.insertBefore(rect, svg.firstChild.nextSibling);
      const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
      label.setAttribute('x', gMinX - pad + 6); label.setAttribute('y', gMinY - pad + 14);
      label.setAttribute('class', 'group-label');
      label.textContent = g.folder + '/';
      svg.insertBefore(label, rect.nextSibling);
    });
  }

  // Search filter
  document.getElementById('search').addEventListener('input', e => {
    const q = e.target.value.toLowerCase();
    let count = 0;
    nodeEls.forEach(el => {
      const match = !q || el.dataset.id.toLowerCase().includes(q);
      el.style.display = match ? '' : 'none'; if (match) count++;
    });
    edgeEls.forEach(el => {
      const sMatch = !q || el.dataset.source.toLowerCase().includes(q);
      const tMatch = !q || el.dataset.target.toLowerCase().includes(q);
      el.style.display = (sMatch && tMatch) ? '' : 'none';
    });
    document.getElementById('count').textContent = q ? count + ' projects' : '';
  });

  document.getElementById('count').textContent = nodes.length + ' projects';
});
</script>
</body>
</html>
''';
}
