import 'dart:async';

import 'package:flutter/material.dart';

import '../../flutter/localization.dart';
import '../../flutter/styles.dart';
import '../../flutter/user_messages.dart';
import '../../models/card.dart' as cardModel;
import '../../view_models/card_view_model.dart';
import '../helpers/save_updates_dialog.dart';

class CreateUpdateCard extends StatefulWidget {
  final cardModel.Card _card;

  CreateUpdateCard(this._card);

  @override
  State<StatefulWidget> createState() => _CreateUpdateCardState();
}

class _CreateUpdateCardState extends State<CreateUpdateCard> {
  bool _addReversedCard = false;
  bool _isChanged = false;
  TextEditingController _frontTextController = TextEditingController();
  TextEditingController _backTextController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  CardViewModel _viewModel;
  final FocusNode _frontSideFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _viewModel = CardViewModel(widget._card);
    if (_viewModel.card.key != null) {
      _frontTextController.text = _viewModel.card.front;
      _backTextController.text = _viewModel.card.back;
    }
  }

  @override
  void dispose() {
    _frontSideFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: () async {
          if (_isChanged) {
            var locale = AppLocalizations.of(context);
            if (_isCardValid()) {
              var saveChangesDialog = await showSaveUpdatesDialog(
                  context: context,
                  changesQuestion: locale.saveChangesQuestion,
                  yesAnswer: locale.save,
                  noAnswer: locale.discard);
              if (saveChangesDialog) {
                try {
                  await _saveCard();
                  return true;
                } catch (e, stackTrace) {
                  UserMessages.showError(
                      () => _scaffoldKey.currentState, e, stackTrace);
                  return false;
                }
              }
            } else {
              var continueEditingDialog = await showSaveUpdatesDialog(
                  context: context,
                  changesQuestion: locale.continueEditingQuestion,
                  yesAnswer: locale.yes,
                  noAnswer: locale.discard);
              if (continueEditingDialog) {
                return false;
              }
            }
          }
          return true;
        },
        child: Scaffold(
          key: _scaffoldKey,
          appBar: _buildAppBar(),
          body: _buildBody(),
        ),
      );

  Widget _buildAppBar() => AppBar(
        title: Text(_viewModel.card.deck.name),
        actions: <Widget>[
          _viewModel.card.key == null
              ? IconButton(
                  icon: Icon(Icons.check),
                  onPressed: _isCardValid() ? _addCard : null)
              : FlatButton(
                  child: Text(
                    AppLocalizations.of(context).save.toUpperCase(),
                    style: _isChanged && _isCardValid()
                        ? TextStyle(color: Colors.white)
                        : null,
                  ),
                  onPressed: _isChanged && _isCardValid()
                      ? () async {
                          // TODO(ksheremet): disable button when writing to db
                          try {
                            await _saveCard();
                          } catch (e, stackTrace) {
                            UserMessages.showError(
                                () => _scaffoldKey.currentState, e, stackTrace);
                            return;
                          }
                          Navigator.of(context).pop();
                        }
                      : null)
        ],
      );

  bool _isCardValid() {
    return _addReversedCard
        ? _frontTextController.text.trim().isNotEmpty &&
            _backTextController.text.trim().isNotEmpty
        : _frontTextController.text.trim().isNotEmpty;
  }

  Future<void> _addCard() async {
    try {
      await _saveCard();
      UserMessages.showMessage(_scaffoldKey.currentState,
          AppLocalizations.of(context).cardAddedUserMessage);
      setState(() {
        _isChanged = false;
        _clearFields();
      });
    } catch (e, stackTrace) {
      UserMessages.showError(() => _scaffoldKey.currentState, e, stackTrace);
    }
  }

  Future<void> _saveCard() async {
    _viewModel.card.front = _frontTextController.text.trim();
    _viewModel.card.back = _backTextController.text.trim();
    await _viewModel.saveCard(_addReversedCard);
  }

  Widget _buildBody() {
    List<Widget> widgetsList = [
      // TODO(ksheremet): limit lines in TextField
      TextField(
        autofocus: true,
        focusNode: _frontSideFocus,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        controller: _frontTextController,
        onChanged: (String text) {
          setState(() {
            _isChanged = true;
          });
        },
        style: AppStyles.primaryText,
        decoration: InputDecoration(
            hintText: AppLocalizations.of(context).frontSideHint),
      ),
      TextField(
        maxLines: null,
        keyboardType: TextInputType.multiline,
        controller: _backTextController,
        onChanged: (String text) {
          setState(() {
            _isChanged = true;
          });
        },
        style: AppStyles.primaryText,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).backSideHint,
        ),
      ),
    ];

    // Add reversed card widget it it is adding cards
    if (_viewModel.card.key == null) {
      // https://github.com/flutter/flutter/issues/254 suggests using
      // CheckboxListTile to have a clickable checkbox label.
      widgetsList.add(CheckboxListTile(
        title: Text(
          AppLocalizations.of(context).reversedCardLabel,
          style: AppStyles.secondaryText,
        ),
        value: _addReversedCard,
        onChanged: (bool newValue) {
          setState(() {
            _addReversedCard = newValue;
          });
        },
        // Position checkbox before the text.
        controlAffinity: ListTileControlAffinity.leading,
      ));
    }

    return ListView(
      padding: EdgeInsets.only(left: 8.0, right: 8.0),
      children: widgetsList,
    );
  }

  void _clearFields() {
    _frontTextController.clear();
    _backTextController.clear();
    // Unset Card key so that we create a one.
    _viewModel.card.key = null;
    FocusScope.of(context).requestFocus(_frontSideFocus);
  }
}
