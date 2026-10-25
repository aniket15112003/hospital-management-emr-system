import 'package:flutter/material.dart';

import '../core/auth/permissions.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon, this.module, this.group);

  final String path;
  final String label;
  final IconData icon;

  /// Module whose `view` permission is required to see the item.
  final String module;
  final String group;
}

const navGroups = ['Main', 'Master Data', 'Administration'];

const navItems = <NavItem>[
  NavItem(
    '/',
    'Dashboard',
    Icons.dashboard_outlined,
    Modules.dashboard,
    'Main',
  ),
  NavItem(
    '/departments',
    'Departments',
    Icons.apartment_outlined,
    Modules.departments,
    'Master Data',
  ),
  NavItem(
    '/doctors',
    'Doctors',
    Icons.medical_services_outlined,
    Modules.doctors,
    'Master Data',
  ),
  NavItem(
    '/users',
    'Users',
    Icons.people_alt_outlined,
    Modules.users,
    'Master Data',
  ),
  NavItem(
    '/opd-charges',
    'OPD Charges',
    Icons.receipt_long_outlined,
    Modules.opdCharges,
    'Master Data',
  ),
  NavItem(
    '/lab-tests',
    'Lab Tests',
    Icons.biotech_outlined,
    Modules.labTests,
    'Master Data',
  ),
  NavItem(
    '/medicines',
    'Medicines',
    Icons.medication_outlined,
    Modules.medicines,
    'Master Data',
  ),
  NavItem(
    '/wards',
    'Wards',
    Icons.local_hospital_outlined,
    Modules.wardsRoomsBeds,
    'Master Data',
  ),
  NavItem(
    '/rooms',
    'Rooms',
    Icons.meeting_room_outlined,
    Modules.wardsRoomsBeds,
    'Master Data',
  ),
  NavItem(
    '/beds',
    'Beds',
    Icons.bed_outlined,
    Modules.wardsRoomsBeds,
    'Master Data',
  ),
  NavItem(
    '/billing-masters',
    'Billing Masters',
    Icons.request_quote_outlined,
    Modules.billingMasters,
    'Master Data',
  ),
  NavItem(
    '/prescription-templates',
    'Prescription Templates',
    Icons.description_outlined,
    Modules.prescriptionTemplates,
    'Master Data',
  ),
  NavItem(
    '/roles',
    'Roles & Permissions',
    Icons.admin_panel_settings_outlined,
    Modules.roles,
    'Administration',
  ),
  NavItem(
    '/numbering',
    'Numbering & Receipts',
    Icons.pin_outlined,
    Modules.numbering,
    'Administration',
  ),
  NavItem(
    '/hospital-profile',
    'Hospital Profile',
    Icons.business_outlined,
    Modules.hospitalProfile,
    'Administration',
  ),
  NavItem(
    '/print-settings',
    'Print Settings',
    Icons.print_outlined,
    Modules.printSettings,
    'Administration',
  ),
  NavItem(
    '/reports',
    'Operational Reports',
    Icons.insert_chart_outlined,
    Modules.reports,
    'Administration',
  ),
  NavItem(
    '/audit-logs',
    'Audit Logs',
    Icons.history_outlined,
    Modules.auditLogs,
    'Administration',
  ),
  NavItem(
    '/backup',
    'Backup & Recovery',
    Icons.backup_outlined,
    Modules.backup,
    'Administration',
  ),
  NavItem(
    '/system-settings',
    'System Settings',
    Icons.settings_outlined,
    Modules.systemSettings,
    'Administration',
  ),
];

NavItem? navItemFor(String location) {
  for (final item in navItems) {
    if (item.path == location) return item;
  }
  return null;
}
