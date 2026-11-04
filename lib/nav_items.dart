import 'package:flutter/material.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.roles, {this.webPath});

  final String label;
  final IconData icon;

  /// Mirrors frontend/src/components/nav-items.ts. Only a menu filter: every API call is checked again on the server.
  final List<String> roles;

  /// Website page for this item: shown inside the app when there is no native screen, else the "Open full version" action.
  final String? webPath;
}

const _all = ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT', 'PLACEMENT', 'FINANCE'];

const navItems = <NavItem>[
  NavItem('Dashboard', Icons.dashboard_outlined, _all, webPath: '/app'),
  NavItem('Admissions', Icons.person_add_alt_outlined, ['ADMIN', 'COORDINATOR'], webPath: '/app/admissions'),
  NavItem('Students', Icons.people_outline, ['ADMIN', 'COORDINATOR', 'TRAINER'], webPath: '/app/students'),
  NavItem('Courses', Icons.menu_book_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT'], webPath: '/app/courses'),
  NavItem('My profile', Icons.account_circle_outlined, ['STUDENT'], webPath: '/app/my-profile'),
  NavItem('My progress', Icons.trending_up, ['STUDENT'], webPath: '/app/my-progress'),
  NavItem('Course requests', Icons.inbox_outlined, ['ADMIN', 'COORDINATOR', 'STUDENT'], webPath: '/app/course-requests'),
  NavItem('Batches', Icons.calendar_month_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER'], webPath: '/app/batches'),
  NavItem('Live classes', Icons.videocam_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT'],
      webPath: '/app/live-classes'),
  NavItem('Question bank', Icons.description_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER'],
      webPath: '/app/lecture-material'),
  NavItem('Assessments', Icons.assignment_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT'],
      webPath: '/app/assessments'),
  NavItem('Finance', Icons.payments_outlined, ['ADMIN', 'COORDINATOR', 'FINANCE', 'STUDENT'], webPath: '/app/finance'),
  NavItem('Certificates', Icons.workspace_premium_outlined, ['ADMIN', 'STUDENT'], webPath: '/app/certificates'),
  NavItem('Placements', Icons.work_outline, ['ADMIN', 'PLACEMENT', 'STUDENT'], webPath: '/app/placements'),
  NavItem('Files', Icons.folder_outlined, _all, webPath: '/app/files'),
  NavItem('ID cards', Icons.badge_outlined, ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT'], webPath: '/app/id-cards'),
  NavItem('Announcements', Icons.campaign_outlined, _all, webPath: '/app/announcements'),
  NavItem('Users', Icons.admin_panel_settings_outlined, ['ADMIN', 'COORDINATOR'], webPath: '/app/users'),
  NavItem('Customize', Icons.tune, ['ADMIN'], webPath: '/app/customize'),
  NavItem('Monitoring', Icons.face_retouching_natural, ['ADMIN'], webPath: '/app/monitoring'),
  NavItem('Audit logs', Icons.fact_check_outlined, ['ADMIN'], webPath: '/app/audit-logs'),
  NavItem('Account', Icons.person_outline, _all),
];
