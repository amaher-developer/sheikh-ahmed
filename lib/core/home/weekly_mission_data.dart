import 'package:flutter/material.dart';

/// A specific, actionable good deed suggested for the week — deliberately
/// concrete (a number, a named surah, a named act) rather than a vague
/// "be good this week", so there's something a person can actually decide
/// they did or didn't do.
class WeeklyMission {
  final String titleKey;
  final String detailKey;
  final IconData icon;

  const WeeklyMission({
    required this.titleKey,
    required this.detailKey,
    required this.icon,
  });
}

/// 52 missions — one for every week of the year.
///
/// The count is the point: [weeklyMission] cycles this list in order, so
/// the list's length *is* the repeat period. At 15 entries a user saw the
/// same mission come round three and a half times a year, which made the
/// card feel static. At 52 nothing repeats within a year.
///
/// Keep this at 52 when editing. Adding a 53rd doesn't break anything, but
/// it does mean the cycle drifts against the calendar year rather than
/// lining up with it.
const kWeeklyMissions = <WeeklyMission>[
  WeeklyMission(
    titleKey: 'weekly_mission.feed_needy_title',
    detailKey: 'weekly_mission.feed_needy_detail',
    icon: Icons.restaurant_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.read_juz_title',
    detailKey: 'weekly_mission.read_juz_detail',
    icon: Icons.menu_book_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.donate_patient_title',
    detailKey: 'weekly_mission.donate_patient_detail',
    icon: Icons.local_hospital_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.fast_mon_thu_title',
    detailKey: 'weekly_mission.fast_mon_thu_detail',
    icon: Icons.no_meals_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.check_family_title',
    detailKey: 'weekly_mission.check_family_detail',
    icon: Icons.family_restroom_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.memorize_mulk_title',
    detailKey: 'weekly_mission.memorize_mulk_detail',
    icon: Icons.auto_stories_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.donate_items_title',
    detailKey: 'weekly_mission.donate_items_detail',
    icon: Icons.checkroom_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.help_neighbor_title',
    detailKey: 'weekly_mission.help_neighbor_detail',
    icon: Icons.elderly_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.memorize_kursi_title',
    detailKey: 'weekly_mission.memorize_kursi_detail',
    icon: Icons.bookmark_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.donate_blood_title',
    detailKey: 'weekly_mission.donate_blood_detail',
    icon: Icons.bloodtype_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.clean_place_title',
    detailKey: 'weekly_mission.clean_place_detail',
    icon: Icons.cleaning_services_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.read_companion_title',
    detailKey: 'weekly_mission.read_companion_detail',
    icon: Icons.history_edu_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.thank_you_note_title',
    detailKey: 'weekly_mission.thank_you_note_detail',
    icon: Icons.mail_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.skip_habit_title',
    detailKey: 'weekly_mission.skip_habit_detail',
    icon: Icons.savings_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.reconcile_title',
    detailKey: 'weekly_mission.reconcile_detail',
    icon: Icons.handshake_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.sunan_rawatib_title',
    detailKey: 'weekly_mission.sunan_rawatib_detail',
    icon: Icons.mosque_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.qiyam_layl_title',
    detailKey: 'weekly_mission.qiyam_layl_detail',
    icon: Icons.nightlight_round,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.duha_title',
    detailKey: 'weekly_mission.duha_detail',
    icon: Icons.wb_sunny_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.learn_tafsir_title',
    detailKey: 'weekly_mission.learn_tafsir_detail',
    icon: Icons.school_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.teach_child_title',
    detailKey: 'weekly_mission.teach_child_detail',
    icon: Icons.child_care_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.visit_sick_title',
    detailKey: 'weekly_mission.visit_sick_detail',
    icon: Icons.healing_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.daily_sadaqah_title',
    detailKey: 'weekly_mission.daily_sadaqah_detail',
    icon: Icons.volunteer_activism_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.sponsor_orphan_title',
    detailKey: 'weekly_mission.sponsor_orphan_detail',
    icon: Icons.escalator_warning_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.water_charity_title',
    detailKey: 'weekly_mission.water_charity_detail',
    icon: Icons.water_drop_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.plant_tree_title',
    detailKey: 'weekly_mission.plant_tree_detail',
    icon: Icons.park_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.istighfar_title',
    detailKey: 'weekly_mission.istighfar_detail',
    icon: Icons.spa_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.salat_nabi_title',
    detailKey: 'weekly_mission.salat_nabi_detail',
    icon: Icons.favorite_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.memorize_kahf_title',
    detailKey: 'weekly_mission.memorize_kahf_detail',
    icon: Icons.auto_stories_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.read_kahf_friday_title',
    detailKey: 'weekly_mission.read_kahf_friday_detail',
    icon: Icons.calendar_today_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.dua_parents_title',
    detailKey: 'weekly_mission.dua_parents_detail',
    icon: Icons.pan_tool_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.visit_parents_title',
    detailKey: 'weekly_mission.visit_parents_detail',
    icon: Icons.home_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.silat_rahim_title',
    detailKey: 'weekly_mission.silat_rahim_detail',
    icon: Icons.diversity_3_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.forgive_title',
    detailKey: 'weekly_mission.forgive_detail',
    icon: Icons.self_improvement_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.control_anger_title',
    detailKey: 'weekly_mission.control_anger_detail',
    icon: Icons.psychology_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.lower_gaze_title',
    detailKey: 'weekly_mission.lower_gaze_detail',
    icon: Icons.visibility_off_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.guard_tongue_title',
    detailKey: 'weekly_mission.guard_tongue_detail',
    icon: Icons.record_voice_over_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.leave_argument_title',
    detailKey: 'weekly_mission.leave_argument_detail',
    icon: Icons.forum_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.early_masjid_title',
    detailKey: 'weekly_mission.early_masjid_detail',
    icon: Icons.access_time_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.first_row_title',
    detailKey: 'weekly_mission.first_row_detail',
    icon: Icons.groups_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.adhkar_after_prayer_title',
    detailKey: 'weekly_mission.adhkar_after_prayer_detail',
    icon: Icons.brightness_low_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.morning_evening_azkar_title',
    detailKey: 'weekly_mission.morning_evening_azkar_detail',
    icon: Icons.wb_twilight_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.tahajjud_title',
    detailKey: 'weekly_mission.tahajjud_detail',
    icon: Icons.bedtime_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.ayyam_beed_title',
    detailKey: 'weekly_mission.ayyam_beed_detail',
    icon: Icons.brightness_3_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.feed_fasting_title',
    detailKey: 'weekly_mission.feed_fasting_detail',
    icon: Icons.dinner_dining_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.gift_mushaf_title',
    detailKey: 'weekly_mission.gift_mushaf_detail',
    icon: Icons.card_giftcard_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.share_knowledge_title',
    detailKey: 'weekly_mission.share_knowledge_detail',
    icon: Icons.lightbulb_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.remove_harm_title',
    detailKey: 'weekly_mission.remove_harm_detail',
    icon: Icons.delete_sweep_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.spread_salam_title',
    detailKey: 'weekly_mission.spread_salam_detail',
    icon: Icons.sentiment_satisfied_alt_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.help_student_title',
    detailKey: 'weekly_mission.help_student_detail',
    icon: Icons.menu_book_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.pay_debt_title',
    detailKey: 'weekly_mission.pay_debt_detail',
    icon: Icons.account_balance_wallet_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.dua_muslims_title',
    detailKey: 'weekly_mission.dua_muslims_detail',
    icon: Icons.public_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.no_complaint_title',
    detailKey: 'weekly_mission.no_complaint_detail',
    icon: Icons.emoji_emotions_rounded,
  ),
];

/// Days since 1 January 1970, counted on the calendar date alone.
///
/// DateTime.utc, not DateTime: the local-time constructor returns an
/// instant that `~/` then truncates *toward zero*, which drops a whole day
/// in any zone ahead of UTC. The week index would then depend on the
/// device's timezone rather than on the date, so two users a few hours
/// apart could see different missions on the same day.
int _epochDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Which Saturday-to-Friday week [date] falls in.
///
/// The -2 is what aligns it: epoch day 0 is Thursday 1 January 1970, so a
/// plain `epochDay ~/ 7` puts the boundary on a **Thursday**. The rest of
/// the app treats Saturday as the start of the week — the tracker's week
/// strip (see saturdayWeekIndex) and the weekly-mission notification, which
/// AdhanScheduler.scheduleWeekly anchors to the upcoming Saturday. So the
/// mission used to roll over on Thursday while the reminder announcing it
/// arrived on Saturday, and the "done" tick reset two days into what the
/// user considered the same week.
int _weekIndex(DateTime date) => (_epochDay(date) - 2) ~/ 7;

/// Picks the week's mission deterministically — cycling through the list
/// in order (like [dailyQuote]) so nothing repeats until every mission has
/// been suggested once, and every device sees the same one in the same
/// calendar week without needing a server.
WeeklyMission weeklyMission(DateTime date) {
  return kWeeklyMissions[_weekIndex(date) % kWeeklyMissions.length];
}

/// A stable per-week storage key — changes exactly when [weeklyMission]'s
/// pick changes, so "did I mark this week's mission done" resets on its
/// own the moment a new mission starts, the same self-resetting pattern
/// used for azkar/tracker progress (see date_key.dart).
String weekKey(DateTime date) => 'w${_weekIndex(date)}';

/// Missions for Ramadan, used in place of the yearly list for the month.
///
/// Kept as its own list rather than mixed into the 52: those cycle by week
/// index across the whole year, so a Ramadan entry landing there would come
/// round in some random week of Sha'ban or Shawwal and read as a mistake.
/// Ramadan moves through the solar year, so its missions cannot be pinned to
/// a week number — they have to be selected by the Hijri month instead.
const kRamadanMissions = <WeeklyMission>[
  WeeklyMission(
    titleKey: 'weekly_mission.ramadan_boxes_title',
    detailKey: 'weekly_mission.ramadan_boxes_detail',
    icon: Icons.inventory_2_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.iftar_meal_title',
    detailKey: 'weekly_mission.iftar_meal_detail',
    icon: Icons.set_meal_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.taraweeh_full_title',
    detailKey: 'weekly_mission.taraweeh_full_detail',
    icon: Icons.mosque_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.juz_a_day_title',
    detailKey: 'weekly_mission.juz_a_day_detail',
    icon: Icons.auto_stories_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.last_ten_qiyam_title',
    detailKey: 'weekly_mission.last_ten_qiyam_detail',
    icon: Icons.nightlight_round,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.zakat_fitr_title',
    detailKey: 'weekly_mission.zakat_fitr_detail',
    icon: Icons.volunteer_activism_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.itikaf_hour_title',
    detailKey: 'weekly_mission.itikaf_hour_detail',
    icon: Icons.self_improvement_rounded,
  ),
  WeeklyMission(
    titleKey: 'weekly_mission.forgive_someone_title',
    detailKey: 'weekly_mission.forgive_someone_detail',
    icon: Icons.handshake_rounded,
  ),
];

/// The mission for [date], taking Ramadan into account.
///
/// During Ramadan the month has roughly four and a half weeks, so the
/// Ramadan list is indexed by which week of the month it is rather than by
/// the year-wide week index — otherwise the month would start on whichever
/// entry the yearly counter happened to land on.
WeeklyMission missionFor(DateTime date, {required bool ramadan, int day = 0}) {
  if (!ramadan) return weeklyMission(date);
  final weekOfRamadan = ((day - 1) ~/ 7).clamp(0, kRamadanMissions.length - 1);
  return kRamadanMissions[weekOfRamadan % kRamadanMissions.length];
}

/// The storage key for [missionFor], so "done this week" resets when the
/// mission changes and not before.
String missionKeyFor(DateTime date, {required bool ramadan, int day = 0}) {
  if (!ramadan) return weekKey(date);
  return 'r${date.year}w${((day - 1) ~/ 7)}';
}
