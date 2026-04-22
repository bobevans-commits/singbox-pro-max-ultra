import 'package:flutter/material.dart';
import 'package:universal_proxy_party/core/models/kernel_config.dart';

/// Dropdown widget for selecting kernel type
class KernelSelector extends StatelessWidget {
  final KernelType? selectedType;
  final ValueChanged<KernelType>? onChanged;

  const KernelSelector({
    super.key,
    this.selectedType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Kernel',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<KernelType>(
          value: selectedType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items: KernelType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Row(
                children: [
                  _getKernelIcon(type),
                  const SizedBox(width: 12),
                  Text(type.name),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _getKernelIcon(KernelType type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case KernelType.singBox:
        iconData = Icons.box;
        iconColor = Colors.blue;
        break;
      case KernelType.v2Ray:
        iconData = Icons.rocket_launch;
        iconColor = Colors.orange;
        break;
      case KernelType.mihomo:
        iconData = Icons.dns;
        iconColor = Colors.green;
        break;
    }

    return Icon(iconData, color: iconColor, size: 24);
  }
}
