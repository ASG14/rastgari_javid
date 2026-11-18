import 'package:flutter/material.dart';

class ProfileTabs extends StatelessWidget {
  const ProfileTabs({
    super.key,
    required this.controller,
    required this.tabs,
    required this.children,
    this.height = 520,
  }) : assert(tabs.length == children.length);

  final TabController controller;
  final List<Widget> tabs;
  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          TabBar(
            controller: controller,
            isScrollable: false,
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurfaceVariant,
            indicatorColor: colors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: tabs,
          ),
          Expanded(
            child: TabBarView(controller: controller, children: children),
          ),
        ],
      ),
    );
  }
}
