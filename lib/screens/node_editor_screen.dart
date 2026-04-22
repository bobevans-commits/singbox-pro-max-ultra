import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/proxy_service.dart';
import '../models/singbox_config.dart';

/// Node editor screen for adding/editing proxy nodes
class NodeEditorScreen extends StatefulWidget {
  final Outbound? existingNode;
  
  const NodeEditorScreen({super.key, this.existingNode});

  @override
  State<NodeEditorScreen> createState() => _NodeEditorScreenState();
}

class _NodeEditorScreenState extends State<NodeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tagController;
  late TextEditingController _serverController;
  late TextEditingController _portController;
  late TextEditingController _uuidController;
  late TextEditingController _passwordController;
  late TextEditingController _securityController;
  late TextEditingController _flowController;
  late TextEditingController _sniController;
  late TextEditingController _pathController;
  late TextEditingController _serviceNameController;
  late TextEditingController _alpnController;
  late TextEditingController _fingerprintController;
  late TextEditingController _publicKeyController;
  late TextEditingController _shortIdController;
  late TextEditingController _upMbpsController;
  late TextEditingController _downMbpsController;
  late TextEditingController _obfsPasswordController;
  late TextEditingController _congestionController;
  
  String _selectedProtocol = 'vmess';
  String _selectedTransport = 'tcp';
  bool _tlsEnabled = false;
  bool _realityEnabled = false;
  bool _insecure = false;
  
  final List<String> _protocols = [
    'vmess', 'vless', 'trojan', 'shadowsocks', 
    'hysteria', 'hysteria2', 'tuic', 'wireguard'
  ];
  
  final List<String> _transports = [
    'tcp', 'ws', 'http', 'grpc', 'quic', 'httpupgrade'
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }
  
  void _initializeControllers() {
    final node = widget.existingNode;
    
    if (node != null) {
      _selectedProtocol = node.type;
      _tagController = TextEditingController(text: node.tag);
      _serverController = TextEditingController(text: node.server ?? '');
      _portController = TextEditingController(text: node.serverPort?.toString() ?? '');
      _uuidController = TextEditingController(text: node.uuid ?? '');
      _passwordController = TextEditingController(text: node.password ?? '');
      _securityController = TextEditingController(text: node.security ?? 'auto');
      _flowController = TextEditingController(text: node.flow ?? '');
      _sniController = TextEditingController(text: node.tls?.serverName ?? '');
      _pathController = TextEditingController(text: node.transport?.path ?? '');
      _serviceNameController = TextEditingController(text: node.transport?.serviceName ?? '');
      _alpnController = TextEditingController(text: node.tls?.alpn ?? '');
      _fingerprintController = TextEditingController(text: node.tls?.utls ?? '');
      _publicKeyController = TextEditingController(text: node.reality?.publicKey ?? '');
      _shortIdController = TextEditingController(text: node.reality?.shortId ?? '');
      _upMbpsController = TextEditingController(text: node.upMbps ?? '');
      _downMbpsController = TextEditingController(text: node.downMbps ?? '');
      _obfsPasswordController = TextEditingController(text: node.obfsPassword ?? '');
      _congestionController = TextEditingController(text: node.congestionControl ?? '');
      
      _tlsEnabled = node.tls?.enabled ?? false;
      _realityEnabled = node.reality?.enabled ?? false;
      _insecure = node.tls?.insecure ?? false;
      _selectedTransport = node.transport?.type ?? 'tcp';
    } else {
      _tagController = TextEditingController();
      _serverController = TextEditingController();
      _portController = TextEditingController();
      _uuidController = TextEditingController();
      _passwordController = TextEditingController();
      _securityController = TextEditingController(text: 'auto');
      _flowController = TextEditingController();
      _sniController = TextEditingController();
      _pathController = TextEditingController();
      _serviceNameController = TextEditingController();
      _alpnController = TextEditingController();
      _fingerprintController = TextEditingController();
      _publicKeyController = TextEditingController();
      _shortIdController = TextEditingController();
      _upMbpsController = TextEditingController();
      _downMbpsController = TextEditingController();
      _obfsPasswordController = TextEditingController();
      _congestionController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _uuidController.dispose();
    _passwordController.dispose();
    _securityController.dispose();
    _flowController.dispose();
    _sniController.dispose();
    _pathController.dispose();
    _serviceNameController.dispose();
    _alpnController.dispose();
    _fingerprintController.dispose();
    _publicKeyController.dispose();
    _shortIdController.dispose();
    _upMbpsController.dispose();
    _downMbpsController.dispose();
    _obfsPasswordController.dispose();
    _congestionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingNode == null ? 'Add Node' : 'Edit Node'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNode,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Protocol Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Protocol', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedProtocol,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.protocol),
                      ),
                      items: _protocols.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (value) => setState(() => _selectedProtocol = value!),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Basic Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Basic Settings', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tagController,
                      decoration: const InputDecoration(
                        labelText: 'Node Name',
                        prefixIcon: Icon(Icons.label),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _serverController,
                            decoration: const InputDecoration(
                              labelText: 'Server',
                              prefixIcon: Icon(Icons.dns),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v?.isEmpty ?? true) return 'Required';
                              final port = int.tryParse(v!);
                              if (port == null || port < 1 || port > 65535) return 'Invalid port';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Authentication (protocol specific)
            if (_showAuthFields()) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Authentication', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      if (_selectedProtocol == 'vmess' || _selectedProtocol == 'vless' || _selectedProtocol == 'tuic') ...[
                        TextFormField(
                          controller: _uuidController,
                          decoration: const InputDecoration(
                            labelText: 'UUID',
                            prefixIcon: Icon(Icons.vpn_key),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ],
                      if (_selectedProtocol == 'trojan' || _selectedProtocol == 'shadowsocks') ...[
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ],
                      if (_selectedProtocol == 'vless') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _flowController,
                          decoration: const InputDecoration(
                            labelText: 'Flow (optional)',
                            hintText: 'xtls-rprx-vision',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Transport Settings
            if (_showTransportSettings()) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transport', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedTransport,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.swap_horiz),
                        ),
                        items: _transports.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (value) => setState(() => _selectedTransport = value!),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedTransport == 'ws' || _selectedTransport == 'http' || _selectedTransport == 'httpupgrade') ...[
                        TextFormField(
                          controller: _pathController,
                          decoration: const InputDecoration(
                            labelText: 'Path',
                            hintText: '/ws',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      if (_selectedTransport == 'grpc') ...[
                        TextFormField(
                          controller: _serviceNameController,
                          decoration: const InputDecoration(
                            labelText: 'Service Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // TLS Settings
            if (_showTlsSettings()) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TLS', style: Theme.of(context).textTheme.titleMedium),
                          Switch(
                            value: _tlsEnabled,
                            onChanged: (v) => setState(() => _tlsEnabled = v),
                          ),
                        ],
                      ),
                      if (_tlsEnabled) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _sniController,
                          decoration: const InputDecoration(
                            labelText: 'SNI',
                            hintText: 'example.com',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Allow Insecure'),
                          subtitle: const Text('Skip certificate verification'),
                          value: _insecure,
                          onChanged: (v) => setState(() => _insecure = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _alpnController,
                          decoration: const InputDecoration(
                            labelText: 'ALPN (optional)',
                            hintText: 'h2,http/1.1',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _fingerprintController,
                          decoration: const InputDecoration(
                            labelText: 'Fingerprint (optional)',
                            hintText: 'chrome',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Reality Settings (for VLESS)
            if (_selectedProtocol == 'vless' && _tlsEnabled) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reality', style: Theme.of(context).textTheme.titleMedium),
                          Switch(
                            value: _realityEnabled,
                            onChanged: (v) => setState(() => _realityEnabled = v),
                          ),
                        ],
                      ),
                      if (_realityEnabled) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _publicKeyController,
                          decoration: const InputDecoration(
                            labelText: 'Public Key',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _shortIdController,
                          decoration: const InputDecoration(
                            labelText: 'Short ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Hysteria/TUIC specific settings
            if (_selectedProtocol == 'hysteria' || _selectedProtocol == 'hysteria2' || _selectedProtocol == 'tuic') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Protocol Specific', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      if (_selectedProtocol.startsWith('hysteria')) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _upMbpsController,
                                decoration: const InputDecoration(
                                  labelText: 'Upload (Mbps)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _downMbpsController,
                                decoration: const InputDecoration(
                                  labelText: 'Download (Mbps)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _obfsPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Obfs Password (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      if (_selectedProtocol == 'tuic') ...[
                        TextFormField(
                          controller: _congestionController,
                          decoration: const InputDecoration(
                            labelText: 'Congestion Control',
                            hintText: 'bbr',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveNode,
                icon: const Icon(Icons.save),
                label: const Text('Save Node', style: TextStyle(fontSize: 16)),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  bool _showAuthFields() {
    return ['vmess', 'vless', 'trojan', 'shadowsocks', 'tuic'].contains(_selectedProtocol);
  }
  
  bool _showTransportSettings() {
    return ['vmess', 'vless', 'trojan', 'shadowsocks'].contains(_selectedProtocol);
  }
  
  bool _showTlsSettings() {
    return ['vmess', 'vless', 'trojan', 'hysteria', 'hysteria2', 'tuic'].contains(_selectedProtocol);
  }
  
  void _saveNode() {
    if (!_formKey.currentState!.validate()) return;
    
    final port = int.tryParse(_portController.text);
    if (port == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid port number')),
      );
      return;
    }
    
    TlsConfig? tls;
    if (_tlsEnabled) {
      tls = TlsConfig(
        enabled: true,
        serverName: _sniController.text.isNotEmpty ? _sniController.text : null,
        insecure: _insecure,
        alpn: _alpnController.text.isNotEmpty ? _alpnController.text : null,
        utls: _fingerprintController.text.isNotEmpty ? _fingerprintController.text : null,
      );
    }
    
    RealityConfig? reality;
    if (_realityEnabled) {
      reality = RealityConfig(
        enabled: true,
        publicKey: _publicKeyController.text.isNotEmpty ? _publicKeyController.text : null,
        shortId: _shortIdController.text.isNotEmpty ? _shortIdController.text : null,
      );
    }
    
    TransportConfig? transport;
    if (_showTransportSettings()) {
      transport = TransportConfig(
        type: _selectedTransport,
        path: _pathController.text.isNotEmpty ? _pathController.text : null,
        serviceName: _serviceNameController.text.isNotEmpty ? _serviceNameController.text : null,
      );
    }
    
    final node = Outbound(
      type: _selectedProtocol,
      tag: _tagController.text,
      server: _serverController.text,
      serverPort: port,
      uuid: _uuidController.text.isNotEmpty ? _uuidController.text : null,
      password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
      security: _securityController.text.isNotEmpty ? _securityController.text : null,
      flow: _flowController.text.isNotEmpty ? _flowController.text : null,
      tls: tls,
      reality: reality,
      transport: transport,
      upMbps: _upMbpsController.text.isNotEmpty ? _upMbpsController.text : null,
      downMbps: _downMbpsController.text.isNotEmpty ? _downMbpsController.text : null,
      obfsPassword: _obfsPasswordController.text.isNotEmpty ? _obfsPasswordController.text : null,
      congestionControl: _congestionController.text.isNotEmpty ? _congestionController.text : null,
    );
    
    final proxyService = context.read<ProxyService>();
    
    if (widget.existingNode != null) {
      // Update existing node
      proxyService.removeOutbound(widget.existingNode!.tag);
    }
    
    proxyService.addOutbound(node);
    
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.existingNode == null ? 'Added' : 'Updated'} node: ${_tagController.text}')),
      );
    }
  }
}
