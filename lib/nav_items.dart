import 'package:flutter/material.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.roles);

  final String label;
  final IconData icon;

  /// Mirrors frontend/src/components/nav-items.ts. Only a menu filter: every API call is checked again on the server.
  final List<String> roles;
}

const _all = ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT', 'PLACEMENT', 'FINANCE'];

const navItems = <NavItem>[
  NavItem('Dashboard', Icons.dashboard_outlined, _all),
  NavItem('Students', Icons.people_outline, ['ADMIN', 'COORDINATOR', 'TRAINER']),
  NavItem('Courses', Icons.menu_book_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT']),
  NavItem('My progress', Icons.trending_up, ['STUDENT']),
  NavItem('Batches', Icons.calendar_month_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER']),
  NavItem('Live classes', Icons.videocam_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT']),
  NavItem('Assessments', Icons.assignment_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT']),
  NavItem('Finance', Icons.payments_outlined, ['ADMIN', 'COORDINATOR', 'FINANCE', 'STUDENT']),
  NavItem('Certificates', Icons.workspace_premium_outlined, ['ADMIN', 'STUDENT']),
  NavItem('Placements', Icons.work_outline, ['ADMIN', 'PLACEMENT', 'STUDENT']),
  NavItem('Files', Icons.folder_outlined, _all),
  NavItem('ID cards', Icons.badge_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT']),
  NavItem('Announcements', Icons.campaign_outlined, _all),
  NavItem('Account', Icons.person_outline, _all),
];
