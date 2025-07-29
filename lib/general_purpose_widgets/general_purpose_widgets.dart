import 'package:flutter/material.dart';
import 'package:get/get.dart';
//import 'dart:convert';
import 'package:dotted_border/dotted_border.dart';
import 'package:intl/intl.dart';


// Helper to capitalize the first letter of a string
extension StringExtension on String {
  String get capitaliseFirst => "${this[0].toUpperCase()}${substring(1)}";
}

// Helper to lighten a color for better text visibility on a colored background
Color lightenColor(Color color, [int amount = 100]) {
  return Color.alphaBlend(Colors.white.withAlpha(amount), color);
}

bool isOverflowing(GlobalKey containerKey, GlobalKey contentKey) {
  final containerBox = containerKey.currentContext?.findRenderObject() as RenderBox?;
  final contentBox = contentKey.currentContext?.findRenderObject() as RenderBox?;

  if (containerBox == null || contentBox == null) return false;

  return contentBox.size.height > containerBox.size.height;
}

/////////////////////////////////////////////////////////////////////////

class GPFormDialog {
  /// ---------------------------------------------------------------------------- ///
  ///  Displays a styled form in a dialog, built dynamically.
  ///
  /// - [title]: The title displayed at the top of the dialog.
  /// - [fields]: A list of maps, where each map defines a form field.
  /// - [initialData]: A map of initial values for the fields, used for "edit" mode.
  /// - [onSubmit]: A callback that receives the form data as a map when submitted.
  /// - [submitButtonText]: The text for the primary submission button.
  /// 
  /// ---------------------------------------------------------------------------- ///
  
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
    final dropdownMenuColor = lightenColor(theme.primaryColor, 70);

    // This map will hold the current state of the form data.
    final Map<String, dynamic> formData = {};

    // Initialise form data with initial values (for edit mode) or defaults.
    for (var field in fields) {
      final key = field['key'];
      if (initialData != null && initialData.containsKey(key)) {
        formData[key] = initialData[key];
      } else {
        formData[key] = field['initialValue'];
      }
    }

    return Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 24),
        title: Text(title),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: SizedBox(
              width: 300, // Fixed width for consistent layout
              // Use a StatefulBuilder to manage the form's state within the dialog.
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: fields.map((field) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildFormField(field, formData, setState, dropdownMenuColor),
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
            onPressed: () => Get.back(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: lightenColor(theme.primaryColor.withAlpha(60), 150),
              backgroundColor: theme.primaryColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            child: Text(submitButtonText),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Get.back(); // why tf does this work, onSubmit should have terminated pretty quick anyways
                onSubmit(formData);
                //Get.back();
              }
            },
          ),
        ],
      ),
      barrierDismissible: false, // Prevent closing by tapping outside
    );
  }

  // Private helper to build a form field based on its definition map.
  static Widget _buildFormField(
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
        return TextFormField(
          initialValue: formData[key] ?? '',
          decoration: InputDecoration(labelText: label),
          maxLines: field['maxLines'] ?? 1,
          validator: (value) =>
              isRequired && (value == null || value.isEmpty) ? 'Please enter a $label' : null,
          onSaved: (value) => formData[key] = value,
        );
      case 'dropdown':
        // Note: The options are expected to be a List<String> for simplicity.
        List<String> options = List<String>.from(field['options']);
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: label),
          dropdownColor: dropdownColor,
          value: formData[key],
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option.capitaliseFirst),
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
      default:
        return Text('Unsupported field type: ${field['type']}');
    }
  }
}

/////////////////////////////////////////////////////////////////////////

class GPSelectableCard extends StatefulWidget {
  // Content Parameters
  final String title;
  final String description;
  final String tagText;
  final Color tagColor;
  final String importanceText;
  final Color importanceColor;
  final DateTime date;
  final Widget expandedChild;

  // Interaction Parameters
  final bool isExpandable;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onClick;

  const GPSelectableCard({
    Key? key,
    required this.title,
    this.description = '',
    required this.tagText,
    this.tagColor = Colors.grey,
    required this.importanceText,
    this.importanceColor = Colors.blue,
    required this.date,
    required this.expandedChild,
    this.isExpandable = true,
    this.onEdit,
    this.onDelete,
    this.onClick,
  }) : super(key: key);

  @override
  _GPSelectableCardState createState() => _GPSelectableCardState();
}

class _GPSelectableCardState extends State<GPSelectableCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: theme.primaryColor.withAlpha(90),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: () {
          // General onClick callback
          widget.onClick?.call();

          // Toggle expansion if expandable
          if (widget.isExpandable) {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          }
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.only(top: 3, right: 12, left: 12, bottom: 12),
          child: Stack(
            children: [
              // Edit and Delete Buttons (Top Right)
              if (widget.onEdit != null || widget.onDelete != null)
                Row(
                  children: [
                    const Spacer(), // Pushes buttons to the right
                    if (widget.onEdit != null)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        iconSize: 20.0,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onEdit,
                      ),
                    if (widget.onEdit != null && widget.onDelete != null)
                      const SizedBox(width: 5),
                    if (widget.onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete),
                        iconSize: 20.0,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onDelete,
                      ),
                  ],
                ),
              // Main Card Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 9),
                  // Top row for tags/labels
                  Row(
                    children: [
                      _buildTag(widget.tagText, widget.tagColor),
                      const SizedBox(width: 6),
                      _buildTag(widget.importanceText, widget.importanceColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Padding(
                    padding: const EdgeInsets.only(right: 80), // Space for buttons
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Description
                  if (widget.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(right: 80), // Space for buttons
                      child: Text(
                        widget.description,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Bottom row for date/icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(widget.date),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Expanded Content
                  if (_isExpanded) ...[
                    const Divider(height: 20, thickness: 1),
                    widget.expandedChild,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build a tag UI
  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.capitaliseFirst,
        style: TextStyle(
            color: lightenColor(color), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/////////////////////////////////////////////////////////////////////////

class GPText extends StatelessWidget {
 final List<TextSpan> textSpans;
 final TextStyle? defaultStyle;

 const GPText({Key? key, required this.textSpans, this.defaultStyle}) : super(key: key);

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

/////////////////////////////////////////////////////////////////////////

class GPPopup {
 static Future<void> show(BuildContext context, {required Widget content}) {
 return showDialog<void>(
 context: context,
 builder: (BuildContext context) {
 return AlertDialog(
 content: content,
 actions: <Widget>[
 TextButton(
 child: const Text('Close'),
 onPressed: () {
 Navigator.of(context).pop();
 },
 ),
 ],
 );
 },
 );
 }
}

/////////////////////////////////////////////////////////////////////////

class GPColumn<T extends Object> extends StatelessWidget {
  final Widget header;
  final Widget body;
  final Widget footer;
  final double width;
  // REMOVED: A flexible widget should not have a fixed height parameter.
  // It determines its own height from its content.
  // final double? height;
  final DragTargetAccept<T> onAccept;
  final Widget? hoverPlaceholder;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? margin;

  const GPColumn({
    Key? key,
    required this.header,
    required this.body,
    required this.footer,
    required this.onAccept,
    this.width = 300.0,
    // this.height, // REMOVED from constructor
    this.hoverPlaceholder,
    this.decoration,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DragTarget<T>(
      onAccept: onAccept,
      builder: (context, candidateData, rejectedData) {
        final isBeingHovered = candidateData.isNotEmpty;
        final theme = Theme.of(context);
        
        // The container no longer has a height property. Its height will be
        // determined by the Column child.
        return Container(
          width: width,
          margin: margin ?? const EdgeInsets.only(right: 16.0),
          decoration: decoration ?? BoxDecoration( // Shadow
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(150),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // Column to size itself to its children.
              mainAxisSize:  MainAxisSize.min,
              children: [
                header,
                const SizedBox(height: 8),
                if (isBeingHovered)
                  _buildHoverUI(context)
                else
                  Container(
                    clipBehavior: Clip.none, // Holy grail
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height - 250, // or whatever offset
                        minHeight: 20
                      ),
                      child: SingleChildScrollView(
                        child: body,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                footer,
              ],
            ),
          ),
        );
      },
    );
  }

  // _buildHoverUI method is unchanged, but it now works correctly.
  Widget _buildHoverUI(BuildContext context) {
    if (hoverPlaceholder != null) {
      return hoverPlaceholder!;
    }
    final theme = Theme.of(context);
    // Added a ConstrainedBox to ensure the drop target has a decent size.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 100),
      child: DottedBorder(
        dashPattern: const [6, 3],
        color: Colors.grey,
        strokeWidth: 2,
        borderType: BorderType.RRect,
        radius: const Radius.circular(12),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: theme.primaryColor.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: Colors.grey, size: 30),
                SizedBox(height: 8),
                Text("Move here!", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
/////////////////////////////////////////////////////////////////////////