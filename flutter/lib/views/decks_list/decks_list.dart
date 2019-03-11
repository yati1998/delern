import 'dart:collection';

import 'package:delern_flutter/flutter/localization.dart';
import 'package:delern_flutter/flutter/styles.dart';
import 'package:delern_flutter/flutter/user_messages.dart';
import 'package:delern_flutter/models/card_model.dart';
import 'package:delern_flutter/models/deck_access_model.dart';
import 'package:delern_flutter/models/deck_model.dart';
import 'package:delern_flutter/view_models/decks_list_bloc.dart';
import 'package:delern_flutter/views/card_create_update/card_create_update.dart';
import 'package:delern_flutter/views/cards_learning/cards_learning.dart';
import 'package:delern_flutter/views/cards_list/cards_list.dart';
import 'package:delern_flutter/views/deck_settings/deck_settings.dart';
import 'package:delern_flutter/views/deck_sharing/deck_sharing.dart';
import 'package:delern_flutter/views/decks_list/create_deck_widget.dart';
import 'package:delern_flutter/views/decks_list/navigation_drawer.dart';
import 'package:delern_flutter/views/helpers/empty_list_message_widget.dart';
import 'package:delern_flutter/views/helpers/observing_animated_list_widget.dart';
import 'package:delern_flutter/views/helpers/search_bar_widget.dart';
import 'package:delern_flutter/views/helpers/sign_in_widget.dart';
import 'package:flutter/material.dart';

class DecksList extends StatefulWidget {
  final String title;

  const DecksList({@required this.title, Key key})
      : assert(title != null),
        super(key: key);

  @override
  _DecksListState createState() => _DecksListState();
}

class _ArrowToFloatingActionButton extends CustomPainter {
  final BuildContext scaffoldContext;
  final GlobalKey fabKey;

  _ArrowToFloatingActionButton(this.scaffoldContext, this.fabKey);

  static const _margin = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final RenderBox scaffoldBox = scaffoldContext.findRenderObject();
    final RenderBox fabBox = fabKey.currentContext.findRenderObject();
    final fabRect =
        scaffoldBox.globalToLocal(fabBox.localToGlobal(Offset.zero)) &
            fabBox.size;
    final center = size.center(Offset.zero);

    final curve = Path()
      ..moveTo(center.dx, center.dy + _margin)
      ..cubicTo(
          center.dx - _margin,
          center.dy + _margin * 2,
          _margin - center.dx,
          (fabRect.center.dy - center.dy) * 2 / 3 + center.dy,
          fabRect.centerLeft.dx - _margin,
          fabRect.center.dy)
      ..moveTo(fabRect.centerLeft.dx - _margin, fabRect.center.dy)
      ..lineTo(
          fabRect.centerLeft.dx - _margin * 2.5, fabRect.center.dy - _margin)
      ..moveTo(fabRect.centerLeft.dx - _margin, fabRect.center.dy)
      ..lineTo(fabRect.centerLeft.dx - _margin * 2.5,
          fabRect.center.dy + _margin / 2);

    canvas.drawPath(
        curve,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_ArrowToFloatingActionButton oldDelegate) =>
      scaffoldContext != oldDelegate.scaffoldContext ||
      fabKey != oldDelegate.fabKey;
}

class ArrowToFloatingActionButtonWidget extends StatelessWidget {
  final Widget child;
  final GlobalKey fabKey;

  const ArrowToFloatingActionButtonWidget({@required this.fabKey, this.child});

  @override
  Widget build(BuildContext context) => Container(
      child: CustomPaint(
          painter: _ArrowToFloatingActionButton(context, fabKey),
          child: child));
}

class _DecksListState extends State<DecksList> {
  DecksListBloc _bloc;

  @override
  void didChangeDependencies() {
    final uid = CurrentUserWidget.of(context).user.uid;
    if (_bloc?.uid != uid) {
      _bloc?.dispose();
      _bloc = DecksListBloc(uid: uid);
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _bloc?.dispose();
    super.dispose();
  }

  void setFilter(String input) {
    if (input == null) {
      _bloc.decksListFilter = null;
      return;
    }
    input = input.toLowerCase();
    _bloc.decksListFilter = (d) =>
        // Case insensitive filter
        d.name.toLowerCase().contains(input);
  }

  GlobalKey fabKey = GlobalKey();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: SearchBarWidget(title: widget.title, search: setFilter),
        drawer: NavigationDrawer(),
        body: Column(
          children: <Widget>[
            Expanded(
              child: ObservingAnimatedListWidget(
                list: _bloc.decksList,
                itemBuilder: (context, item, animation, index) =>
                    SizeTransition(
                      child: DeckListItemWidget(item, _bloc),
                      sizeFactor: animation,
                    ),
                emptyMessageBuilder: () => ArrowToFloatingActionButtonWidget(
                    fabKey: fabKey,
                    child: EmptyListMessageWidget(
                        AppLocalizations.of(context).emptyDecksList)),
              ),
            ),
            // The size of FAB = 56 logical pixels from Material Design.
            // To make settings available that are behind Fab, padding=60 was
            // added.
            const Padding(
              padding: EdgeInsets.only(bottom: 60),
            )
          ],
        ),
        floatingActionButton: CreateDeckWidget(key: fabKey),
      );
}

class DeckListItemWidget extends StatelessWidget {
  final DeckModel deck;
  final DecksListBloc bloc;

  const DeckListItemWidget(this.deck, this.bloc);

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Container(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: _buildDeckName(context),
                ),
                _buildNumberOfCards(context),
                _buildDeckMenu(context),
                DeckMenu(),
              ],
            ),
          ),
          const Divider(height: 1.0),
        ],
      );

  Widget _buildDeckName(BuildContext context) => Material(
        child: InkWell(
          splashColor: Theme.of(context).splashColor,
          onTap: () async {
            var anyCardsShown = await Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/decks/learn'),
                  // TODO(dotdoom): pass scheduled cards list to CardsLearning.
                  builder: (context) => CardsLearning(deck: deck),
                ));
            if (anyCardsShown == false) {
              // If deck is empty, open a screen with adding cards
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      settings: const RouteSettings(name: '/cards/new'),
                      builder: (context) => CardCreateUpdate(
                          card: CardModel(deckKey: deck.key), deck: deck)));
            }
          },
          child: Container(
            padding: const EdgeInsets.only(
                top: 14.0, bottom: 14.0, left: 8.0, right: 8.0),
            child: Text(
              deck.name,
              style: AppStyles.primaryText,
            ),
          ),
        ),
      );

  Widget _buildNumberOfCards(BuildContext context) => StreamBuilder<int>(
        key: Key(deck.key),
        initialData: bloc.numberOfCardsDue(deck.key).value,
        stream: bloc.numberOfCardsDue(deck.key).stream,
        builder: (context, snapshot) => Container(
              child: Text(snapshot.data?.toString() ?? 'N/A',
                  style: AppStyles.primaryText),
            ),
      );

  Widget _buildDeckMenu(BuildContext context) => Material(
        child: InkResponse(
          splashColor: Theme.of(context).splashColor,
          radius: 15.0,
          onTap: () {},
          child: PopupMenuButton<_DeckMenuItemType>(
            onSelected: (itemType) =>
                _onDeckMenuItemSelected(context, itemType),
            itemBuilder: (context) => _buildMenu(context)
                .entries
                .map((entry) => DeckPopupMenuItem<_DeckMenuItemType>(
                      value: entry.key,
                      child: RaisedButton(
                        color: Colors.tealAccent,
                        padding: EdgeInsets.all(8.0),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                        child: Text(
                          entry.value,
                          style: AppStyles.secondaryText,
                        ),
                        onPressed: () {},
                      ),
                    ))
                .toList(),
          ),
        ),
      );

  void _onDeckMenuItemSelected(BuildContext context, _DeckMenuItemType item) {
    // Not allow to add/edit or delete cards with read access
    // If some error occurred and it is null access
    // we still give a try to edit for a user. If user
    // doesn't have permissions they will see "Permission
    // denied".
    var allowEdit = deck.access != AccessType.read;
    switch (item) {
      case _DeckMenuItemType.add:
        if (allowEdit) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  settings: const RouteSettings(name: '/cards/new'),
                  builder: (context) => CardCreateUpdate(
                        card: CardModel(deckKey: deck.key),
                        deck: deck,
                      )));
        } else {
          UserMessages.showMessage(Scaffold.of(context),
              AppLocalizations.of(context).noAddingWithReadAccessUserMessage);
        }
        break;
      case _DeckMenuItemType.edit:
        Navigator.push(
          context,
          MaterialPageRoute(
              settings: const RouteSettings(name: '/decks/view'),
              builder: (context) => CardsList(
                    deck: deck,
                    allowEdit: allowEdit,
                  )),
        );
        break;
      case _DeckMenuItemType.setting:
        Navigator.push(
          context,
          MaterialPageRoute(
              settings: const RouteSettings(name: '/decks/settings'),
              builder: (context) => DeckSettings(deck)),
        );
        break;
      case _DeckMenuItemType.share:
        if (deck.access == AccessType.owner) {
          Navigator.push(
            context,
            MaterialPageRoute(
                settings: const RouteSettings(name: '/decks/share'),
                builder: (context) => DeckSharing(deck)),
          );
        } else {
          UserMessages.showMessage(Scaffold.of(context),
              AppLocalizations.of(context).noSharingAccessUserMessage);
        }
        break;
    }
  }
}

class DeckPopupMenuItem<T> extends PopupMenuItem<T> {
  const DeckPopupMenuItem({@required value, @required Widget child})
      : assert(child != null),
        super(value: value, child: child);

  @override
  _DeckPopupMenuState<T> createState() => _DeckPopupMenuState();
}

class _DeckPopupMenuState<T>
    extends PopupMenuItemState<T, DeckPopupMenuItem<T>> {
  /*@override
  Widget buildChild() => RaisedButton(
        color: Colors.tealAccent,
        padding: EdgeInsets.all(8.0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
        child: Text('Add'),
        onPressed: () {},
      );*/
}

class DeckMenu extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _DeckMenuState();
}

class _DeckMenuState extends State<DeckMenu>
    with SingleTickerProviderStateMixin {
  Animation<Alignment> moveAnimation;
  Animation<double> opacityAnimation;
  AnimationController controller;
  final duration = Duration(milliseconds: 270);

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: duration);

    final anim = CurvedAnimation(parent: controller, curve: Curves.linear);
    moveAnimation = Tween<Alignment>(
            begin: Alignment.centerRight, end: Alignment.bottomRight)
        .animate(anim);
    opacityAnimation = Tween(begin: 0.0, end: 1.0).animate(anim);
  }

  Widget getItem(String menuItemName) => RaisedButton(
        color: Colors.tealAccent,
        padding: EdgeInsets.all(8.0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
        child: Text(menuItemName),
        onPressed: () {
          controller.reverse();
        },
      );

  Widget buildPrimaryItem(IconData source) {
    const size = 45.0;
    return Material(
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: size,
        height: size,
        child: Icon(
          source,
        ),
      ),
    );
  }

  final double expandedSize = 180.0;
  final double hiddenSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final menu = _buildMenu(context);

    return AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Container(
              width: 100,
              height:
                  hiddenSize + (expandedSize - hiddenSize) * controller.value,
              child: Stack(
                children: <Widget>[
                  FadeTransition(
                    opacity: opacityAnimation,
                    child: Align(
                        alignment: moveAnimation.value,
                        child: Container(
                            padding: EdgeInsets.only(bottom: 90),
                            child: getItem(menu[_DeckMenuItemType.add]))),
                  ),
                  FadeTransition(
                    opacity: opacityAnimation,
                    child: Align(
                        alignment: moveAnimation.value,
                        child: Container(
                          padding: EdgeInsets.only(bottom: 50),
                          child: getItem(menu[_DeckMenuItemType.edit]),
                        )),
                  ),
                  FadeTransition(
                    opacity: opacityAnimation,
                    child: Align(
                        alignment: moveAnimation.value,
                        child: getItem(menu[_DeckMenuItemType.setting])),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                        onTap: () {
                          controller.isCompleted
                              ? controller.reverse()
                              : controller.forward();
                        },
                        child: buildPrimaryItem(
                            controller.isCompleted || controller.isAnimating
                                ? Icons.close
                                : Icons.more_vert)),
                  )
                ],
              ),
            ));
  }
}

enum _DeckMenuItemType { add, edit, setting, share }

Map<_DeckMenuItemType, String> _buildMenu(BuildContext context) {
  // We want this Map to be ordered.
  // ignore: prefer_collection_literals
  var deckMenu = LinkedHashMap<_DeckMenuItemType, String>()
    ..[_DeckMenuItemType.add] = AppLocalizations.of(context).addCardsDeckMenu
    ..[_DeckMenuItemType.edit] = AppLocalizations.of(context).editCardsDeckMenu
    ..[_DeckMenuItemType.setting] =
        AppLocalizations.of(context).settingsDeckMenu;

  if (!CurrentUserWidget.of(context).user.isAnonymous) {
    deckMenu[_DeckMenuItemType.share] =
        AppLocalizations.of(context).shareDeckMenu;
  }
  return deckMenu;
}
