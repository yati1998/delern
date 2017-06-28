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

package org.dasfoo.delern.adapters;

import com.firebase.ui.database.FirebaseRecyclerAdapter;
import com.google.firebase.database.Query;

import org.dasfoo.delern.R;
import org.dasfoo.delern.handlers.OnCardViewHolderClick;
import org.dasfoo.delern.models.Card;
import org.dasfoo.delern.models.Deck;
import org.dasfoo.delern.models.helpers.FirebaseSnapshotParser;
import org.dasfoo.delern.util.LogUtil;
import org.dasfoo.delern.viewholders.CardViewHolder;

/**
 * Created by katarina on 11/19/16.
 */

public class CardRecyclerViewAdapter extends FirebaseRecyclerAdapter<Card, CardViewHolder> {

    private final OnCardViewHolderClick mOnCardViewHolderClick;

    /**
     * Create a new FirebaseRecyclerAdapter.
     *
     * @param deck     deck which cards to show.
     * @param query    reference to FB to cards of deck.
     * @param listener listener to handle clicks on card.
     */
    public CardRecyclerViewAdapter(final Deck deck,
                                   final Query query,
                                   final OnCardViewHolderClick listener) {
        super(new FirebaseSnapshotParser<>(Card.class, deck),
                R.layout.card_text_view_for_deck, CardViewHolder.class, query);
        this.mOnCardViewHolderClick = listener;
    }

    /**
     * {@inheritDoc}
     */
    @Override
    protected void populateViewHolder(final CardViewHolder viewHolder, final Card card,
                                      final int position) {
        viewHolder.getFrontTextView().setText(card.getFront());
        viewHolder.getBackTextView().setText(card.getBack());
        viewHolder.setOnViewClick(mOnCardViewHolderClick);
    }
}
