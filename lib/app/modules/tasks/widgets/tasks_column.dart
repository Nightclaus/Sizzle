import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';

class TasksColumn<T extends Object> extends StatelessWidget {
  final Widget header;
  final Widget body;
  final Widget footer;
  final double width;
  final DragTargetAccept<T> onAccept;
  final Widget? hoverPlaceholder;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? margin;

  const TasksColumn({
    Key? key,
    required this.header,
    required this.body,
    required this.footer,
    required this.onAccept,
    this.width = 300.0,
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

        return Container(
          width: width,
          margin: margin ?? const EdgeInsets.only(right: 16.0),
          decoration: decoration ?? BoxDecoration( 
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
              mainAxisSize:  MainAxisSize.min,
              children: [
                header,
                const SizedBox(height: 8),
                if (isBeingHovered)
                  _buildHoverUI(context)
                else
                  Container(
                    clipBehavior: Clip.none, 
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height - 250, 
                        minHeight: 10
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

  Widget _buildHoverUI(BuildContext context) {
    if (hoverPlaceholder != null) {
      return hoverPlaceholder!;
    }
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 100),
      child: DottedBorder(
        dashPattern: const [6, 3],
        color: Colors.grey,
        strokeWidth: 2,
        borderType: BorderType.RRect,
        radius: const Radius.circular(12),
        child: Container(
          height: 200,
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
