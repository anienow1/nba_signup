import 'package:boom_signup/database/event_handler.dart';
import 'package:boom_signup/database/firestore_services.dart';
import 'package:boom_signup/models/event.dart';
import 'package:boom_signup/themes.dart';
import 'package:boom_signup/utils.dart';
import 'package:boom_signup/widgets/delete_confirmation_popup.dart';
import 'package:boom_signup/widgets/info_popup.dart';
import 'package:flutter/material.dart';
import 'package:boom_signup/widgets/date_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Event> events = [];
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = true;
  bool hasNoEntries = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    _isLoading = true;
    List<Event> dbEvents = await FirestoreDatabase.instance.getEvents();

    final weekdays = Weekday.values;
    final weekdayEvents = await Future.wait(
      weekdays.map((day) => getDate(day, dbEvents)),
    );

    for (Event event in dbEvents) {
      if (!(weekdayEvents.contains(event)) && event.id != null) {
        FirestoreDatabase.instance.deleteEvent(event.id!);
      }
    }

    hasNoEntries = true;
    for (Event event in weekdayEvents) {
      if (event.entries != null && event.entries!.isNotEmpty) {
        hasNoEntries = false;
        break;
      }
    }

    setState(() {
      events.clear();
      events.addAll(weekdayEvents);
      events.sort(sortEventsWithTodayFirst);
      _isLoading = false;
    });
  }

  Future<Event> getDate(Weekday day, List<Event> dbEvents) async {
    Event? event = EventHandler.fetchWeekdayEvent(dbEvents, day);
    if (event != null) return event;
    final newEvent = Event(EventHandler.getNextWeekday(day));
    final newId = await FirestoreDatabase.instance.insertEvent(newEvent);
    return Event(newEvent.date, entries: newEvent.entries, id: newId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _renderAppBar(),
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          _renderLowerTitle(),
          Expanded(child: SingleChildScrollView(child: _renderBody())),
        ],
      ),
    );
  }

  AppBar _renderAppBar() {
    return AppBar(
      backgroundColor: AppColors.black,
      leading: Padding(
        padding: EdgeInsets.all(AppPadding.small),
        child: Image.asset(("lib/assets/gac-icon.png"), width: 24, height: 24),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: AppPadding.small),
          child: _renderPopupButton(),
        ),
      ],
    );
  }

  Widget _renderPopupButton() {
    return ElevatedButton(
      onPressed: () {
        _infoEntered(context);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [ //
          Image.asset(("lib/assets/basketball.png"), width: 20, height: 20),
          SizedBox(width: AppPadding.normal),
          Text('Signup (Click Here)', style: AppTextStyles.appBarButton),
          SizedBox(width: AppPadding.normal),
          Image.asset(("lib/assets/basketball.png"), width: 20, height: 20),
        ],
      ),
    );
  }

  Widget _renderBody() {
    if (_isLoading) return SizedBox.shrink();
    if (hasNoEntries) return _renderEmpty();
    return Padding(
      padding: EdgeInsets.only(top: AppPadding.normal),
      child: _renderEventList(),
    );
  }

  Widget _renderLowerTitle() {
    return Container(
      color: AppColors.black,
      padding: EdgeInsets.only(
        left: AppPadding.normal,
        right: AppPadding.normal,
        bottom: AppPadding.normal,
        top: AppPadding.extraSmall,
      ),
      child: Text(
        "NBA Signup",
        style: AppTextStyles.mainTitle.copyWith(color: AppColors.white),
        textAlign: .center,
      ),
    );
  }

  Widget _renderEmpty() {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppPadding.large,
        left: AppPadding.normal,
      ),
      child: Text('Nobody signed up yet!', style: AppTextStyles.noEvents),
    );
  }

  Widget _renderEventList() {
    return Column(
      children: events
          .map(
            (event) => Padding(
              padding: EdgeInsets.only(
                left: AppPadding.normal,
                right: AppPadding.normal,
                bottom: AppPadding.small,
              ),
              child: DateWidget(event, onEntryDelete: onEntryDelete),
            ),
          )
          .toList(),
    );
  }

  Future<void> _infoEntered(BuildContext context) async {
    final data = await InformationPopup.showSignupDialog(context);
    if (data != null) {
      Event? eventToEdit;
      for (Event event in events) {
        if (dateToWeekday(event.date) == data.day) {
          eventToEdit = event;
          break;
        }
      }
      if (eventToEdit == null) {
        debugPrint('No matching event found for day ${data.day}.');
        return;
      }
      String id = DateTime.now().microsecondsSinceEpoch.toString();
      Entry entry = Entry(data.name, data.time, id: id);
      eventToEdit.addPerson(entry);
      await FirestoreDatabase.instance.addEntry(eventToEdit, entry);
      await _loadEvents();
    }
  }

  Future<void> onEntryDelete(Event event, Entry entry) async {
    final confirmed = await DeleteConfirmationPopup.show(context, entry.person);
    if (confirmed) {
      if (event.id != null && entry.id != null) {
        await FirestoreDatabase.instance.deleteEntry(event, entry);
        await _loadEvents();
      }
    }
  }
}
