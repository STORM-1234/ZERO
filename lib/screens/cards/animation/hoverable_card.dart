// File: lib/screens/widgets/hoverable_card.dart

import 'package:flutter/material.dart';

class HoverableCard extends StatefulWidget {
  final Widget child;

  const HoverableCard({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _HoverableCardState createState() => _HoverableCardState();
}

class _HoverableCardState extends State<HoverableCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        isHovered = true;
      }),
      onExit: (_) => setState(() {
        isHovered = false;
      }),
      child: AnimatedScale(
        scale: isHovered ? 1.05 : 1.0, // Scale up by 5% on hover
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black, // Darkest black background
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.cyanAccent, width: 2), // Neon cyan border
            boxShadow: isHovered
                ? [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.7),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ]
                : [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: widget.child,
        ),
      ),
    );
  }
}
