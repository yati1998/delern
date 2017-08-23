/*
 * Copyright (C) 2017 Katarina Sheremet
 * This file is part of Delern.
 *
 * Delern is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * Delern is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with  Delern.  If not, see <http://www.gnu.org/licenses/>.
 */

package org.dasfoo.delern.presenters;

import org.dasfoo.delern.models.Card;
import org.dasfoo.delern.views.IAddEditCardView;

/**
 * Presenter for AddEditCardActivity. It handles adding and updating card logic
 * and calls callbacks methods to update view for user.
 * TODO(ksheremet): split into 2 different classes; perhaps even 2 interfaces for a view
 * (can still be a single Activity implementing 2 interfaces)
 */
public class AddEditCardActivityPresenter {

    private final IAddEditCardView mAddEditCardView;
    private Card mCard;

    /**
     * Constructor for Presenter. It gets interface as parameter that implemented
     * in Activity to do callbacks.
     *
     * @param addEditCardView interface for performing callbacks.
     * @param card            card for updating or empty for adding.
     */
    public AddEditCardActivityPresenter(final IAddEditCardView addEditCardView, final Card card) {
        this.mAddEditCardView = addEditCardView;
        this.mCard = card;
    }

    /**
     * OnCreate method that called from AddEditCardActivity.onCreate.
     * It checks whether user is going to add new cards or update existing cards.
     * It calls callback method in AddEditCardActivity to initialize views accordingly.
     */
    public void onCreate() {
        if (mCard.exists()) {
            mAddEditCardView.initForUpdate(mCard.getFront(), mCard.getBack());
        } else {
            mAddEditCardView.initForAdd();
        }
    }

    /**
     * Method updates existing card in FB.
     *
     * @param newFront new front side of card.
     * @param newBack  new back side of card.
     */
    @SuppressWarnings("CheckReturnValue")
    private void update(final String newFront, final String newBack) {
        mCard.setFront(newFront);
        mCard.setBack(newBack);
        mCard.save().subscribe(mAddEditCardView::cardUpdated);
    }

    /**
     * Method for adding card to FB.
     *
     * @param front text on front side of card.
     * @param back  text on back side of card.
     */
    @SuppressWarnings("CheckReturnValue")
    private void add(final String front, final String back) {
        mCard.setFront(front);
        mCard.setBack(back);
        mCard.create().subscribe(mAddEditCardView::cardAdded);
    }

    /**
     * Performs when user wants to add or update cards.
     *
     * @param front front side of card.
     * @param back  back side of card.
     */
    @SuppressWarnings({"ArgumentParameterSwap", "ArgumentParameterMismatch"})
    public void onAddUpdate(final String front, final String back) {
        if (mCard.exists()) {
            update(front, back);
        } else {
            add(front, back);
            if (mAddEditCardView.addReversedCard()) {
                Card card = new Card(mCard.getDeck());
                card.setFront(back);
                card.setBack(front);
                mCard = card;
                add(back, front);
            }
        }
    }
}
