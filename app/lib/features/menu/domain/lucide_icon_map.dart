import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// sjapp 메뉴 트리의 `iconClass` 필드는 Lucide 아이콘 이름(PascalCase).
/// 앱은 Material Symbols만 쓰므로 lookup 테이블이 필요하다.
/// 알려지지 않은 이름은 [fallback]으로 떨어진다.
///
/// 매핑 출처: 메뉴 트리의 실제 iconClass 값과 custom_menu_tree.dart에서
/// 클라이언트 가상 항목이 쓰는 이름들.
const _kLucideToSymbols = <String, IconData>{
  'Armchair': Symbols.event_seat,
  'Award': Symbols.workspace_premium,
  'Bell': Symbols.notifications,
  'BookMarked': Symbols.bookmarks,
  'BookOpen': Symbols.menu_book,
  'BookOpenCheck': Symbols.fact_check,
  'Briefcase': Symbols.work,
  'Building': Symbols.apartment,
  'Calendar': Symbols.calendar_month,
  'CalendarCheck': Symbols.event_available,
  'CalendarDays': Symbols.date_range,
  'Campaign': Symbols.campaign,
  'ChartColumn': Symbols.bar_chart,
  'CircleDollarSign': Symbols.paid,
  'ClipboardList': Symbols.assignment,
  'Clock': Symbols.schedule,
  'Cog': Symbols.settings,
  'CreditCard': Symbols.credit_card,
  'DoorOpen': Symbols.door_open,
  'Facebook': Symbols.thumb_up,
  'FileCheck': Symbols.assignment_turned_in,
  'FileSearch': Symbols.find_in_page,
  'FileText': Symbols.article,
  'Forum': Symbols.forum,
  'Globe': Symbols.language,
  'GraduationCap': Symbols.school,
  'Groups': Symbols.groups,
  'Headset': Symbols.headset_mic,
  'HelpCircle': Symbols.help,
  'LampDesk': Symbols.desk,
  'Landmark': Symbols.account_balance,
  'Layers': Symbols.layers,
  'LayoutDashboard': Symbols.dashboard,
  'Library': Symbols.local_library,
  'LocalLibrary': Symbols.local_library,
  'Map': Symbols.map,
  'MapPin': Symbols.location_on,
  'Megaphone': Symbols.campaign,
  'MonitorSpeaker': Symbols.desktop_windows,
  'Newspaper': Symbols.newspaper,
  'Phone': Symbols.phone,
  'Receipt': Symbols.receipt,
  'ReceiptText': Symbols.receipt_long,
  'Rss': Symbols.rss_feed,
  'School': Symbols.school,
  'Science': Symbols.science,
  'Settings': Symbols.settings,
  'ShieldAlert': Symbols.gpp_maybe,
  'ShieldCheck': Symbols.verified_user,
  'Star': Symbols.star,
  'Table': Symbols.table_chart,
  'TabletSmartphone': Symbols.tablet_android,
  'TrendingUp': Symbols.trending_up,
  'Tv': Symbols.tv,
  'UserCircle': Symbols.account_circle,
  'UserPlus': Symbols.person_add,
  'Users': Symbols.groups,
  'Utensils': Symbols.restaurant,
  'Vote': Symbols.how_to_vote,
  'Wallet': Symbols.wallet,
  'Wrench': Symbols.build,
  'Youtube': Symbols.play_circle,
};

IconData lucideToSymbol(
  String lucide, {
  IconData fallback = Symbols.chevron_right,
}) {
  if (lucide.isEmpty) return fallback;
  return _kLucideToSymbols[lucide] ?? fallback;
}
