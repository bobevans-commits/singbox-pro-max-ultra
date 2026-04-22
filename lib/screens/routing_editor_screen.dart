import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/proxy_service.dart';
import '../models/singbox_config.dart';

/// Routing rule editor screen
class RoutingEditorScreen extends StatefulWidget {
  final RuleConfig? existingRule;

  const RoutingEditorScreen({super.key, this.existingRule});

  @override
  State<RoutingEditorScreen> createState() => _RoutingEditorScreenState();
}

class _RoutingEditorScreenState extends State<RoutingEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _outboundController;
  late TextEditingController _domainController;
  late TextEditingController _domainSuffixController;
  late TextEditingController _ipCidrController;
  late TextEditingController _protocolController;
  late TextEditingController _sourcePortController;
  late TextEditingController _inboundController;

  String _ruleType = 'domain'; // domain, ip, protocol, port

  final List<String> _outboundOptions = ['direct', 'proxy', 'block', 'dns-out'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final rule = widget.existingRule;

    if (rule != null) {
      _outboundController = TextEditingController(text: rule.outbound);
      _domainController = TextEditingController(text: rule.domain?.join(', ') ?? '');
      _domainSuffixController = TextEditingController(text: rule.domainSuffix?.join(', ') ?? '');
      _ipCidrController = TextEditingController(text: rule.ipCidr?.join(', ') ?? '');
      _protocolController = TextEditingController(text: rule.protocol ?? '');
      _sourcePortController = TextEditingController(text: rule.sourcePort?.toString() ?? '');
      _inboundController = TextEditingController(text: rule.inbound ?? '');

      if (rule.domain != null && rule.domain!.isNotEmpty) {
        _ruleType = 'domain';
      } else if (rule.domainSuffix != null && rule.domainSuffix!.isNotEmpty) {
        _ruleType = 'domain_suffix';
      } else if (rule.ipCidr != null && rule.ipCidr!.isNotEmpty) {
        _ruleType = 'ip';
      } else if (rule.protocol != null) {
        _ruleType = 'protocol';
      } else {
        _ruleType = 'domain';
      }
    } else {
      _outboundController = TextEditingController(text: 'proxy');
      _domainController = TextEditingController();
      _domainSuffixController = TextEditingController();
      _ipCidrController = TextEditingController();
      _protocolController = TextEditingController();
      _sourcePortController = TextEditingController();
      _inboundController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _outboundController.dispose();
    _domainController.dispose();
    _domainSuffixController.dispose();
    _ipCidrController.dispose();
    _protocolController.dispose();
    _sourcePortController.dispose();
    _inboundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proxyService = context.watch<ProxyService>();
    final availableOutbounds = proxyService.currentConfig?.outbounds
            .where((o) => ['direct', 'proxy', 'block', 'dns-out'].contains(o.type) || o.type == 'selector')
            .map((o) => o.tag)
            .toList() ??
        ['direct', 'proxy', 'block', 'dns-out'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingRule == null ? 'Add Routing Rule' : 'Edit Routing Rule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveRule(availableOutbounds),
            tooltip: 'Save',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rule Type', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'domain', label: Text('Domain'), icon: Icon(Icons.dns)),
                        ButtonSegment(value: 'domain_suffix', label: Text('Domain Suffix'), icon: Icon(Icons.link)),
                        ButtonSegment(value: 'ip', label: Text('IP CIDR'), icon: Icon(Icons.ip)),
                        ButtonSegment(value: 'protocol', label: Text('Protocol'), icon: Icon(Icons.protocol)),
                        ButtonSegment(value: 'port', label: Text('Port'), icon: Icon(Icons.numbers)),
                      ],
                      selected: {_ruleType},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() => _ruleType = selection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Outbound Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outbound', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Traffic matching this rule will use this outbound',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _outboundController.text.isNotEmpty ? _outboundController.text : availableOutbounds.first,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.output),
                      ),
                      items: availableOutbounds.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                      onChanged: (value) => _outboundController.text = value!,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Rule Condition Fields based on type
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Condition', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),

                    if (_ruleType == 'domain') ...[
                      TextFormField(
                        controller: _domainController,
                        decoration: const InputDecoration(
                          labelText: 'Domains',
                          hintText: 'google.com, youtube.com',
                          helperText: 'Comma-separated full domain names',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.dns),
                        ),
                        maxLines: 3,
                      ),
                    ],

                    if (_ruleType == 'domain_suffix') ...[
                      TextFormField(
                        controller: _domainSuffixController,
                        decoration: const InputDecoration(
                          labelText: 'Domain Suffixes',
                          hintText: '.google.com, .youtube.com',
                          helperText: 'Comma-separated domain suffixes (include the dot)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                        maxLines: 3,
                      ),
                    ],

                    if (_ruleType == 'ip') ...[
                      TextFormField(
                        controller: _ipCidrController,
                        decoration: const InputDecoration(
                          labelText: 'IP CIDR Ranges',
                          hintText: '192.168.0.0/16, 10.0.0.0/8',
                          helperText: 'Comma-separated IP CIDR ranges',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.ip),
                        ),
                        maxLines: 3,
                      ),
                    ],

                    if (_ruleType == 'protocol') ...[
                      TextFormField(
                        controller: _protocolController,
                        decoration: const InputDecoration(
                          labelText: 'Protocol',
                          hintText: 'http, tls, dns, ssh',
                          helperText: 'Protocol name to match',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.protocol),
                        ),
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ],

                    if (_ruleType == 'port') ...[
                      TextFormField(
                        controller: _sourcePortController,
                        decoration: const InputDecoration(
                          labelText: 'Source Port',
                          hintText: '80, 443',
                          helperText: 'Port number to match',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Required';
                          final port = int.tryParse(v!);
                          if (port == null || port < 1 || port > 65535) return 'Invalid port';
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Optional: Inbound filter
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Optional Filters', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _inboundController,
                      decoration: const InputDecoration(
                        labelText: 'Inbound Tag (optional)',
                        hintText: 'Apply rule only to specific inbound',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.input),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _saveRule(availableOutbounds),
                icon: const Icon(Icons.save),
                label: const Text('Save Rule', style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 24),

            // Preset rules
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Presets', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Tap to add common routing rules',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PresetChip(
                          label: 'Direct LAN',
                          onTap: () => _addPresetRule('direct', ipCidr: '192.168.0.0/16,10.0.0.0/8,172.16.0.0/12'),
                        ),
                        _PresetChip(
                          label: 'Proxy Google',
                          onTap: () => _addPresetRule('proxy', domainSuffix: '.google.com,.youtube.com,.gmail.com'),
                        ),
                        _PresetChip(
                          label: 'Block Ads',
                          onTap: () => _addPresetRule('block', domainSuffix: '.ads.com,.adserver.com'),
                        ),
                        _PresetChip(
                          label: 'DNS Direct',
                          onTap: () => _addPresetRule('dns-out', protocol: 'dns'),
                        ),
                        _PresetChip(
                          label: 'China Direct',
                          onTap: () => _addPresetRule('direct', domainSuffix: '.cn'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addPresetRule(String outbound, {String? domainSuffix, String? ipCidr, String? protocol}) {
    setState(() {
      _outboundController.text = outbound;
      if (domainSuffix != null) {
        _domainSuffixController.text = domainSuffix;
        _ruleType = 'domain_suffix';
      } else if (ipCidr != null) {
        _ipCidrController.text = ipCidr;
        _ruleType = 'ip';
      } else if (protocol != null) {
        _protocolController.text = protocol;
        _ruleType = 'protocol';
      }
    });
  }

  void _saveRule(List<String> availableOutbounds) {
    if (!_formKey.currentState!.validate()) return;

    final outbound = _outboundController.text.isNotEmpty ? _outboundController.text : availableOutbounds.first;

    List<String>? domains;
    List<String>? domainSuffixes;
    List<String>? ipCidrs;
    String? protocol;
    int? sourcePort;

    switch (_ruleType) {
      case 'domain':
        if (_domainController.text.isNotEmpty) {
          domains = _domainController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        break;
      case 'domain_suffix':
        if (_domainSuffixController.text.isNotEmpty) {
          domainSuffixes = _domainSuffixController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        break;
      case 'ip':
        if (_ipCidrController.text.isNotEmpty) {
          ipCidrs = _ipCidrController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        break;
      case 'protocol':
        protocol = _protocolController.text.trim();
        break;
      case 'port':
        sourcePort = int.tryParse(_sourcePortController.text.trim());
        break;
    }

    // Validate that at least one condition is set
    if (domains == null && domainSuffixes == null && ipCidrs == null && protocol == null && sourcePort == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify at least one condition')),
      );
      return;
    }

    final rule = RuleConfig(
      outbound: outbound,
      domain: domains,
      domainSuffix: domainSuffixes,
      ipCidr: ipCidrs,
      protocol: protocol,
      sourcePort: sourcePort,
      inbound: _inboundController.text.isNotEmpty ? _inboundController.text : null,
    );

    final proxyService = context.read<ProxyService>();

    if (widget.existingRule != null) {
      // Update: remove old and add new
      final currentRules = List<RuleConfig>.from(proxyService.currentConfig?.route.rules ?? []);
      currentRules.removeWhere((r) => r == widget.existingRule);
      currentRules.add(rule);
      proxyService.updateRoutingRules(currentRules);
    } else {
      // Add new rule
      final currentRules = List<RuleConfig>.from(proxyService.currentConfig?.route.rules ?? []);
      currentRules.add(rule);
      proxyService.updateRoutingRules(currentRules);
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Routing rule saved')),
      );
    }
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      avatar: const Icon(Icons.add_circle_outline, size: 18),
    );
  }
}
