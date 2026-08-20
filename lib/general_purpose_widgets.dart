import 'package:flutter/material.dart';
import 'package:get/get.dart';

bool isOverflowing(GlobalKey containerKey, GlobalKey contentKey) {
  final containerBox = containerKey.currentContext?.findRenderObject() as RenderBox?;
  final contentBox = contentKey.currentContext?.findRenderObject() as RenderBox?;

  if (containerBox == null || contentBox == null) return false;

  return contentBox.size.height > containerBox.size.height;
}

class GPWFormDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> fields,
    required Function(Map<String, dynamic>) onSubmit,
    Map<String, dynamic>? initialData,
    String submitButtonText = 'Submit',
  }) async {
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    final dropdownMenuColor = theme.primaryColor;

    final Map<String, dynamic> formData = {};

    for (var field in fields) {
      final key = field['key'];
      if (initialData != null && initialData.containsKey(key)) {
        formData[key] = initialData[key];
      } else {
        formData[key] = field['initialValue'];
      }
    }

    // FIX: Using standard showDialog with its own isolated dialogContext
    // This stops Get.back() from losing track of what to close.
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 24),
          title: Text(title),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: 300, 
                child: StatefulBuilder(
                  builder: (BuildContext stfContext, StateSetter setState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: fields.map((field) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildFormField(
                              stfContext, field, formData, setState, dropdownMenuColor),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              child: const Text('Cancel'),
              // FIX: Reliably pops only the dialog itself
              onPressed: () => Navigator.pop(dialogContext), 
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimary,
                backgroundColor: theme.primaryColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              child: Text(submitButtonText),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  
                  // FIX: Close the dialog securely right away.
                  Navigator.pop(dialogContext);
                  
                  // Execute business logic afterwards.
                  onSubmit(formData); 
                }
              },
            ),
          ],
        );
      },
    );
  }

  static Widget _buildFormField(
    BuildContext context,
    Map<String, dynamic> field,
    Map<String, dynamic> formData,
    StateSetter setState,
    Color dropdownColor,
  ) {
    String key = field['key'];
    String label = field['label'];
    bool isRequired = field['required'] ?? false;

    switch (field['type']) {
      case 'text':
        // NEW: 'numeric' opt-in gives a numeric keyboard and validates the
        // value parses as a number (on top of the existing required
        // check) — added for record fields like weight/price/quantity.
        // Existing callers that don't set 'numeric' are unaffected.
        final bool numeric = field['numeric'] == true;
        return TextFormField(
          initialValue: formData[key]?.toString() ?? '',
          decoration: InputDecoration(labelText: label),
          maxLines: field['maxLines'] ?? 1,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'Please enter a $label';
            }
            if (numeric &&
                value != null &&
                value.isNotEmpty &&
                double.tryParse(value) == null) {
              return 'Enter a valid number';
            }
            return null;
          },
          onSaved: (value) => formData[key] = value,
        );
      case 'dropdown':
        List<String> options = List<String>.from(field['options']);
        
        // FIX: If the initial data string doesn't match an option EXACTLY, 
        // the dialog crashes silently. This ensures it's perfectly safe.
        if (!options.contains(formData[key])) {
          formData[key] = options.isNotEmpty ? options.first : null;
        }

        return DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: label),
          dropdownColor: dropdownColor,
          value: formData[key],
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                formData[key] = value;
              });
            }
          },
          onSaved: (value) => formData[key] = value,
          validator: (value) =>
              isRequired && value == null ? 'Please select a $label' : null,
        );
      case 'toggle':
        return SwitchListTile(
          title: Text(label),
          value: formData[key] ?? false,
          onChanged: (value) {
            setState(() {
              formData[key] = value;
            });
          },
          contentPadding: EdgeInsets.zero,
        );
      case 'date':
        // NEW. formData[key] holds a DateTime? directly (not a String) —
        // callers should treat 'date' fields as DateTime in onSubmit.
        // 'nullable': true shows a clear button and "Not set" instead of
        // forcing a value. NOTE: this isn't a FormField, so it doesn't
        // participate in formKey.currentState!.validate() — a required
        // date left untouched won't block submission the way a required
        // text/dropdown field does. Callers should default it themselves
        // if that matters (see record_form_dialog.dart for the pattern).
        final bool nullable = field['nullable'] == true;
        final DateTime? current = formData[key] as DateTime?;
        return InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: current ?? DateTime.now(),
              firstDate: DateTime(1990),
              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            );
            if (picked != null) {
              setState(() => formData[key] = picked);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: nullable && current != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => formData[key] = null),
                    )
                  : null,
            ),
            child: Text(
              current == null
                  ? (nullable ? 'Not set' : 'Select a date')
                  : '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}',
              style: current == null
                  ? const TextStyle(color: Colors.black45)
                  : null,
            ),
          ),
        );
      default:
        return Text('Unsupported field type: ${field['type']}');
    }
  }
}

class GPWText extends StatelessWidget {
 final List<TextSpan> textSpans;
 final TextStyle? defaultStyle;

 const GPWText({Key? key, required this.textSpans, this.defaultStyle}) : super(key: key);

 @override
 Widget build(BuildContext context) {
 return RichText(
 text: TextSpan(
 style: defaultStyle ?? DefaultTextStyle.of(context).style,
 children: textSpans,
 ),
 );
 }
}

class GPPopup {
  static Future<void> show({
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) {
    return Get.dialog(
      AlertDialog(
        title: Text(title),
        content: content,
        actions: actions ??
            [
              TextButton(
                child: const Text('Close'),
                onPressed: () => Get.back(),
              ),
            ],
      ),
      barrierDismissible: false,
    );
  }
}