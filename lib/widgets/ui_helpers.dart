import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Number input field with decimal support
Widget numField(TextEditingController controller, String label,
        {double width = 150}) =>
    SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\.eE]')),
        ],
      ),
    );

/// Integer input field
Widget intField(TextEditingController controller, String label,
        {double width = 150}) =>
    SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );

/// Soft colored info box
Widget softBox(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.10)),
      ),
      child: child,
    );

/// Warning box
Widget warnBox(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.25)),
      ),
      child: child,
    );