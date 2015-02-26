Require Import Arith.
Require Import NPeano.
Require Import Omega.
Require Import PeanoNat.
Import Nat.
Require Import List.
Require Import Coq.Numbers.Natural.Abstract.NDiv.
Import ListNotations.
Require Import Sorting.Permutation.

Require Import Util.
Require Import Net.
Require Import RaftState.
Require Import Raft.
Require Import VerdiTactics.
Require Import UpdateLemmas.

Local Arguments update {_} {_} {_} _ _ _ _ : simpl never.

Section CommonTheorems.
  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Definition uniqueIndices (xs : list entry) : Prop :=
    NoDup (map eIndex xs).

  Lemma uniqueIndices_elim_eq :
    forall xs x y,
      uniqueIndices xs ->
      In x xs ->
      In y xs ->
      eIndex x = eIndex y ->
      x = y.
  Proof.
    unfold uniqueIndices.
    eauto using NoDup_map_elim.
  Qed.

  Fixpoint sorted log :=
    match log with
      | [] => True
      | e :: es =>
        (forall e',
           In e' es ->
           eIndex e > eIndex e' /\ eTerm e >= eTerm e') /\
        sorted es
    end.

  Lemma sorted_cons :
    forall xs a,
      sorted xs ->
      (forall a', In a' xs -> eIndex a > eIndex a' /\ eTerm a >= eTerm a') ->
      sorted (a :: xs).
  Proof.
    intros.
    simpl in *. intuition;
      find_apply_hyp_hyp; intuition.
  Qed.

  Lemma sorted_subseq :
    forall ys xs,
      subseq xs ys ->
      sorted ys ->
      sorted xs.
  Proof.
    induction ys; intros; simpl in *.
    - break_match; intuition.
    - break_match; intuition.
      subst. apply sorted_cons; eauto.
      intros. eauto using subseq_In.
  Qed.

  Theorem maxIndex_is_max :
    forall l e,
      sorted l ->
      In e l ->
      maxIndex l >= eIndex e.
  Proof.
    induction l; intros.
    - simpl in *. intuition.
    - simpl in *. intuition.
      + subst. auto with *.
      + find_apply_hyp_hyp. omega.
  Qed.

  Theorem S_maxIndex_not_in :
    forall l e,
      sorted l ->
      eIndex e = S (maxIndex l) ->
      ~ In e l.
  Proof.
    intros. intro.
    find_apply_lem_hyp maxIndex_is_max; auto.
    subst. omega.
  Qed.

  Lemma removeAfterIndex_subseq :
    forall l i,
      subseq (removeAfterIndex l i) l.
  Proof.
    induction l; intros; simpl; auto.
    repeat break_match; intuition.
    - find_inversion. eauto using subseq_refl.
    - right. find_reverse_rewrite. auto.
  Qed.

  Lemma removeAfterIndex_sorted :
    forall l i,
      sorted l ->
      sorted (removeAfterIndex l i).
  Proof.
    intros. eauto using removeAfterIndex_subseq, sorted_subseq.
  Qed.

  Lemma removeAfterIndex_in :
    forall l i a,
      In a (removeAfterIndex l i) ->
      In a l.
  Proof.
    eauto using removeAfterIndex_subseq, subseq_In.
  Qed.


  Lemma findAtIndex_not_in :
    forall l e,
      sorted l ->
      findAtIndex l (eIndex e) = None ->
      ~ In e l.
  Proof.
    induction l; intros; intro.
    - intuition.
    - simpl in *. break_match; try discriminate. intuition.
      + subst. rewrite <- beq_nat_refl in *. discriminate.
      + find_copy_apply_hyp_hyp. intuition. break_if; do_bool; eauto. omega.
  Qed.

  Lemma findAtIndex_in :
    forall l i e',
      findAtIndex l i = Some e' ->
      In e' l.
  Proof.
    induction l; intros.
    - discriminate.
    - simpl in *. break_match.
      + find_inversion. auto.
      + break_if; eauto; discriminate.
  Qed.

  Lemma findAtIndex_index :
    forall l i e',
      findAtIndex l i = Some e' ->
      i = eIndex e'.
  Proof.
    induction l; intros.
    - discriminate.
    - simpl in *. break_match.
      + find_inversion. apply beq_nat_true in Heqb. auto.
      + break_if; eauto; discriminate.
  Qed.

  Lemma NoDup_removeAfterIndex :
    forall l i,
      NoDup l ->
      NoDup (removeAfterIndex l i).
  Proof.
    eauto using subseq_NoDup, removeAfterIndex_subseq.
  Qed.

  Notation disjoint xs ys := (forall x, In x xs -> In x ys -> False).

  Lemma removeAfterIndex_le_In :
    forall xs i x,
      eIndex x <= i ->
      In x xs ->
      In x (removeAfterIndex xs i).
  Proof.
    induction xs; intros.
    - intuition.
    - simpl in *. break_if; simpl in *; intuition.
      subst. do_bool. omega.
  Qed.

  Lemma removeAfterIndex_In_le :
    forall xs i x,
      sorted xs ->
      In x (removeAfterIndex xs i) ->
      eIndex x <= i.
  Proof.
    induction xs; intros.
    - simpl in *. intuition.
    - simpl in *.
      break_if; simpl in *; do_bool; intuition; subst; auto.
      find_apply_hyp_hyp. omega.
  Qed.

  Lemma removeAfterIndex_covariant :
    forall xs ys i x,
      sorted xs ->
      sorted ys ->
      In x (removeAfterIndex xs i) ->
      (forall x, In x xs -> In x ys) ->
      In x (removeAfterIndex ys i).
  Proof.
    induction xs; intros.
    - simpl in *. intuition.
    - simpl in *.
      break_match; simpl in *; intuition;
      subst; do_bool;
      match goal with
        | e : entry, H : forall _, _ = _ \/ _ -> _ |- _ =>
          specialize (H e)
      end;
      intuition.
      + eauto using removeAfterIndex_le_In.
      + find_apply_hyp_hyp. intuition.
        match goal with
          | _ : eIndex ?e <= ?li, _ : eIndex ?e > eIndex ?e' |- _ =>
            assert (eIndex e' <= li) by omega
        end.
        eauto using removeAfterIndex_le_In.
  Qed.

  Lemma removeAfterIndex_le :
    forall xs i j,
      i <= j ->
      removeAfterIndex xs i = removeAfterIndex (removeAfterIndex xs j) i.
  Proof.
    induction xs; intros.
    - reflexivity.
    - simpl.
      find_copy_apply_hyp_hyp.
      repeat (break_if; simpl in *; intuition); try discriminate.
      do_bool. omega.
  Qed.

  Lemma removeAfterIndex_2_subseq :
    forall xs i j,
      subseq (removeAfterIndex (removeAfterIndex xs i) j) (removeAfterIndex (removeAfterIndex xs j) i).
  Proof.
    induction xs; intros; simpl.
    - auto.
    - repeat (break_match; simpl); intuition; try discriminate.
      + eauto using subseq_refl.
      + do_bool. assert (j < i) by omega.
        rewrite removeAfterIndex_le with (j := i) (i := j) at 1; auto; omega.
      + do_bool. assert (i < j) by omega.
        rewrite removeAfterIndex_le with (i := i) (j := j) at 2; auto; omega.
  Qed.

  Lemma removeAfterIndex_comm :
    forall xs i j,
      removeAfterIndex (removeAfterIndex xs i) j =
      removeAfterIndex (removeAfterIndex xs j) i.
  Proof.
    auto using subseq_subseq_eq, removeAfterIndex_2_subseq.
  Qed.

  Lemma removeAfterIndex_2_eq_min :
    forall xs i j,
      removeAfterIndex (removeAfterIndex xs i) j =
      removeAfterIndex xs (min i j).
  Proof.
    intros.
    pose proof Min.min_spec i j. intuition.
    - find_rewrite. rewrite removeAfterIndex_le with (i := i) (j := j) at 2;
        eauto using removeAfterIndex_comm; omega.
    - find_rewrite.
      rewrite <- removeAfterIndex_le with (i := j) (j := i);
        auto; omega.
  Qed.

  Lemma findAtIndex_None :
    forall xs i x,
      sorted xs ->
      findAtIndex xs i = None ->
      In x xs ->
      eIndex x <> i.
  Proof.
    induction xs; intros; simpl in *; intuition; break_match; try discriminate.
    - subst. do_bool. congruence.
    - do_bool. break_if; eauto.
      do_bool. find_apply_hyp_hyp. intuition.
  Qed.

  Lemma findAtIndex_removeAfterIndex_agree :
    forall xs i j e e',
      NoDup (map eIndex xs) ->
      findAtIndex xs i = Some e ->
      findAtIndex (removeAfterIndex xs j) i = Some e' ->
      e = e'.
  Proof.
    intros.
    eapply NoDup_map_elim with (f := eIndex); eauto using findAtIndex_in, removeAfterIndex_in.
    apply findAtIndex_index in H0.
    apply findAtIndex_index in H1.
    congruence.
  Qed.

  Lemma subseq_uniqueIndices :
    forall ys xs,
      subseq xs ys ->
      uniqueIndices ys ->
      uniqueIndices xs.
  Proof.
    unfold uniqueIndices.
    induction ys; intros.
    - simpl in *. break_match; intuition.
    - simpl in *. break_match; intuition.
      + simpl. constructor.
      + subst. simpl in *. invc H0. constructor; auto.
        intro. apply H3.
        eapply subseq_In; eauto.
        apply subseq_map. auto.
      + subst. invc H0. eauto.
  Qed.

  Lemma subseq_findGtIndex :
    forall xs i,
      subseq (findGtIndex xs i) xs.
  Proof.
    induction xs; intros.
    - simpl. auto.
    - simpl. repeat break_match; auto.
      + find_inversion. eauto.
      + congruence.
  Qed.

  Lemma findGtIndex_in :
    forall xs i x,
      In x (findGtIndex xs i) ->
      In x xs.
  Proof.
    eauto using subseq_In, subseq_findGtIndex.
  Qed.

  Lemma findGtIndex_sufficient :
    forall e entries x,
      sorted entries ->
      In e entries ->
      eIndex e > x ->
      In e (findGtIndex entries x).
  Proof.
    induction entries; intros.
    - simpl in *. intuition.
    - simpl in *. break_if; intuition.
      + subst. in_crush.
      + subst. do_bool. omega.
      + do_bool. find_apply_hyp_hyp. omega.
  Qed.

  Definition contiguous_range_exact_lo xs lo :=
    (forall i,
       lo < i <= maxIndex xs ->
       exists e,
         eIndex e = i /\
         In e xs) /\
    (forall e,
       In e xs ->
       lo < eIndex e).

  Lemma removeAfterIndex_uniqueIndices :
    forall l i,
      uniqueIndices l ->
      uniqueIndices (removeAfterIndex l i).
  Proof with eauto using subseq_uniqueIndices, removeAfterIndex_subseq.
    intros...
  Qed.

  Lemma maxIndex_subset :
    forall xs ys,
      sorted xs -> sorted ys ->
      (forall x, In x xs -> In x ys) ->
      maxIndex xs <= maxIndex (orig_base_params:=orig_base_params) ys.
  Proof.
    destruct xs; intros.
    - simpl. omega.
    - destruct ys; simpl in *.
      + match goal with
          | [ H : forall _, _ = _ \/ _ -> _, a : entry |- _ ] =>
            solve [ specialize (H a); intuition ]
        end.
    + match goal with
        | [ H : forall _, _ = _ \/ _ -> _ |- eIndex ?a <= _ ] =>
          specialize (H a); intuition
      end; subst; auto.
      find_apply_hyp_hyp. omega.
  Qed.

  Lemma maxIndex_exists_in :
    forall xs,
      maxIndex xs >= 1 ->
      exists x,
        eIndex x = maxIndex xs /\
        In x xs.
  Proof.
    destruct xs; intros.
    - simpl in *. omega.
    - simpl in *. eauto.
  Qed.

  Lemma maxIndex_app :
    forall l l',
      maxIndex (l ++ l') = maxIndex l \/
      maxIndex (l ++ l') = maxIndex l' /\ l = [].
  Proof.
    induction l; intuition.
  Qed.

  Lemma maxIndex_removeAfterIndex_le :
    forall l i,
      sorted l ->
      maxIndex (removeAfterIndex l i) <= maxIndex l.
  Proof.
    intros.
    apply maxIndex_subset; eauto using removeAfterIndex_sorted.
    intros. eauto using removeAfterIndex_in.
  Qed.

  Lemma maxIndex_removeAfterIndex :
    forall l i e,
      sorted l ->
      In e l ->
      eIndex e = i ->
      maxIndex (removeAfterIndex l i) = i.
  Proof.
    induction l; intros; simpl in *; intuition.
    - subst. break_if; do_bool; try omega.
      reflexivity.
    - break_if; simpl in *.
      + do_bool.
        match goal with
          | H : forall _, In _ _ -> _ |- _ =>
            specialize (H2 e)
        end. intuition. omega.
      + eauto.
  Qed.

  Lemma removeIncorrect_new_contiguous :
    forall new current prev e,
      sorted current ->
      uniqueIndices current ->
      (forall e e',
         eIndex e = eIndex e' ->
         eTerm e = eTerm e' ->
         In e new ->
         In e' current ->
         e = e') ->
      contiguous_range_exact_lo current 0 ->
      contiguous_range_exact_lo new prev ->
      In e current ->
      eIndex e = prev ->
      contiguous_range_exact_lo (new ++ removeAfterIndex current prev)
                                0.
  Proof.
    intros new current prev e Hsorted Huniq Hinv. intros. red. intros.
    intuition.
    - destruct (le_lt_dec i prev).
      + unfold contiguous_range_exact_lo in *. intuition.
        match goal with
          | H: forall _, _ < _ <= _ current -> _, H' : In _ current |- _ =>
            specialize (H i); apply maxIndex_is_max in H'; auto; forward H; intuition
        end. 
        break_exists. exists x. intuition.
        apply in_or_app. right. subst.
        eapply removeAfterIndex_le_In; eauto. 
      + pose proof maxIndex_app new (removeAfterIndex current prev). intuition.
        * find_rewrite.
          unfold contiguous_range_exact_lo in *. intuition.
          match goal with
            | H: forall _, _ < _ <= _ new -> _ |- _ =>
              specialize (H i); auto; forward H; intuition
          end. break_exists. exists x. intuition.
        * subst. simpl in *. clean.
          exfalso.
          pose proof maxIndex_removeAfterIndex current (eIndex e) e.
          intuition.
    - unfold contiguous_range_exact_lo in *.
      do_in_app. intuition.
      + firstorder.
      + firstorder using removeAfterIndex_in.
  Qed.

  Lemma incoming_entries_in_log :
    forall es log x i,
      In x es ->
      uniqueIndices log ->
      exists y,
        eIndex x = eIndex y /\
        eTerm x = eTerm y /\
        In y (es ++ (removeAfterIndex log i)).
  Proof.
    intros.
    exists x. intuition.
  Qed.

  Lemma findGtIndex_necessary :
    forall entries e x,
      In e (findGtIndex entries x) ->
      In e entries /\
      eIndex e > x.
  Proof.
    induction entries; intros; simpl in *; intuition.
    - break_if; simpl in *; intuition; right; eapply IHentries; eauto.
    - break_if;
      simpl in *; intuition.
      + do_bool. subst. omega.
      + simpl in *; intuition; eapply IHentries; eauto.
  Qed.

  Lemma findGtIndex_contiguous :
    forall entries x,
      sorted entries ->
      (forall i, 0 < i <= maxIndex entries -> (exists e, In e entries /\ eIndex e = i)) ->
      forall i, x < i <= maxIndex entries ->
           exists e, In e (findGtIndex entries x) /\ eIndex e = i.
  Proof.
    intros entries x Hsorted; intros. specialize (H i).
    conclude H ltac:(omega).
    break_exists. exists x0. intuition.
    apply findGtIndex_sufficient; auto; omega.
  Qed.

  Lemma findGtIndex_max :
    forall entries x,
      maxIndex (findGtIndex entries x) <= maxIndex entries.
  Proof.
    intros. destruct entries; simpl; auto.
    break_if; simpl; intuition.
  Qed.

  Lemma findAtIndex_uniq_equal :
    forall e e' es,
      findAtIndex es (eIndex e) = Some e' ->
      In e es ->
      uniqueIndices es ->
      e = e'.
  Proof.
    intros.
    pose proof findAtIndex_in _ _ _ H.
    pose proof findAtIndex_index _ _ _ H.
    eapply uniqueIndices_elim_eq; eauto.
  Qed.

  Definition entries_match entries entries' :=
    forall e e' e'',
      eIndex e = eIndex e' ->
      eTerm e = eTerm e' ->
      In e entries ->
      In e' entries' ->
      eIndex e'' <= eIndex e ->
      (In e'' entries <-> In e'' entries').

  Definition entries_match' entries entries' :=
    forall e e' e'',
      eIndex e = eIndex e' ->
      eTerm e = eTerm e' ->
      In e entries ->
      In e' entries' ->
      eIndex e'' <= eIndex e ->
      (In e'' entries -> In e'' entries').

  Lemma entries_match_entries_match' :
    forall xs ys,
      entries_match xs ys ->
      entries_match' xs ys /\
      entries_match' ys xs.
  Proof.
    unfold entries_match, entries_match'.
    intros. intuition.
    - eapply H; eauto.
    - eapply (H e' e); eauto with *.
  Qed.

  Definition contiguous
             (prevLogIndex : logIndex)
             (prevLogTerm : term)
             (leaderLog entries : list entry) : Prop :=
    (prevLogIndex = 0 \/
     exists e, findAtIndex leaderLog prevLogIndex = Some e /\
          eTerm e = prevLogTerm) /\
    (forall e,
       In e leaderLog ->
       eIndex e > prevLogIndex ->
       eIndex e <= maxIndex entries ->
       In e entries) /\
    forall e e',
      eIndex e = eIndex e' ->
      eTerm e = eTerm e' ->
      In e entries ->
      In e' leaderLog ->
      e = e'.

  Lemma entries_match_refl :
    forall l,
      entries_match l l.
  Proof.
    unfold entries_match. intuition.
  Qed.

  Lemma entries_match_sym :
    forall xs ys,
      entries_match xs ys ->
      entries_match ys xs.
  Proof.
    intros.
    unfold entries_match in *.
    intros. intuition.
    - apply H with (e:=e')(e':=e); auto.
      repeat find_rewrite. auto.
    - apply H with (e:=e')(e':=e); auto.
      repeat find_rewrite. auto.
  Qed.

  Lemma advanceCurrentTerm_same_log :
    forall st t,
      log (advanceCurrentTerm st t) = log st.
  Proof.
    unfold advanceCurrentTerm. intros.
    break_if; auto.
  Qed.

  Lemma tryToBecomeLeader_same_log :
    forall n st out st' ms,
      tryToBecomeLeader n st = (out, st', ms) ->
      log st' = log st.
  Proof.
    unfold tryToBecomeLeader.
    intros. find_inversion. auto.
  Qed.

  Lemma handleRequestVote_same_log :
    forall n st t c li lt st' ms,
      handleRequestVote n st t c li lt = (st', ms) ->
      log st' = log st.
  Proof.
    unfold handleRequestVote.
    intros.
    repeat (break_match; try discriminate; repeat (find_inversion; simpl in *));
      auto using advanceCurrentTerm_same_log.
  Qed.

  Lemma handleRequestVoteReply_same_log :
    forall n st src t v,
      log (handleRequestVoteReply n st src t v) = log st.
  Proof.
    unfold handleRequestVoteReply.
    intros. repeat break_match; simpl; auto using advanceCurrentTerm_same_log.
  Qed.


  Lemma advanceCurrentTerm_same_lastApplied :
    forall st t,
      lastApplied (advanceCurrentTerm st t) = lastApplied st.
  Proof.
    unfold advanceCurrentTerm. intros.
    break_if; auto.
  Qed.

  Lemma tryToBecomeLeader_same_lastApplied :
    forall n st out st' ms,
      tryToBecomeLeader n st = (out, st', ms) ->
      lastApplied st' = lastApplied st.
  Proof.
    unfold tryToBecomeLeader.
    intros. find_inversion. auto.
  Qed.

  Lemma handleRequestVote_same_lastApplied :
    forall n st t c li lt st' ms,
      handleRequestVote n st t c li lt = (st', ms) ->
      lastApplied st' = lastApplied st.
  Proof.
    unfold handleRequestVote.
    intros.
    repeat (break_match; try discriminate; repeat (find_inversion; simpl in *));
      auto using advanceCurrentTerm_same_lastApplied.
  Qed.

  Lemma handleRequestVoteReply_same_lastApplied :
    forall n st src t v,
      lastApplied (handleRequestVoteReply n st src t v) = lastApplied st.
  Proof.
    unfold handleRequestVoteReply.
    intros. repeat break_match; simpl; auto using advanceCurrentTerm_same_lastApplied.
  Qed.
  
  Lemma findAtIndex_elim :
    forall l i e,
      findAtIndex l i = Some e ->
      i = eIndex e /\ In e l.
  Proof.
    eauto using findAtIndex_in, findAtIndex_index.
  Qed.

  Lemma index_in_bounds :
    forall e es i,
      sorted es ->
      In e es ->
      i <> 0 ->
      i <= eIndex e ->
      1 <= i <= maxIndex es.
  Proof.
    intros. split.
    - omega.
    - etransitivity; eauto. apply maxIndex_is_max; auto.
  Qed.

  Lemma rachet :
    forall x x' xs ys,
      eIndex x = eIndex x' ->
      In x xs ->
      In x' ys ->
      In x' xs ->
      uniqueIndices xs ->
      In x ys.
  Proof.
    intros.
    assert (x = x').
    - eapply uniqueIndices_elim_eq; eauto.
    - subst. auto.
  Qed.

  Lemma findAtIndex_intro :
    forall l i e,
      sorted l ->
      In e l ->
      eIndex e = i ->
      uniqueIndices l ->
      findAtIndex l i = Some e.
  Proof.
    induction l; intros.
    - simpl in *. intuition.
    - simpl in *. intuition; break_if; subst; do_bool.
      + auto.
      + congruence.
      + f_equal. eauto using uniqueIndices_elim_eq with *.
      + break_if; eauto.
        * do_bool. find_apply_hyp_hyp. omega.
        * eapply IHl; auto. unfold uniqueIndices in *.
          simpl in *. solve_by_inversion.
  Qed.

  Lemma doLeader_same_log :
    forall st n os st' ms,
      doLeader st n = (os, st', ms) ->
      log st' = log st.
  Proof.
    unfold doLeader.
    intros.
    repeat break_match; repeat find_inversion; auto.
  Qed.

  Lemma handleAppendEntriesReply_same_log :
    forall n st src t es b st' l,
      handleAppendEntriesReply n st src t es b = (st', l) ->
      log st' = log st.
  Proof.
    intros.
    unfold handleAppendEntriesReply in *.
    repeat (break_match; repeat (find_inversion; simpl in *)); auto using advanceCurrentTerm_same_log.
  Qed.

  Lemma handleAppendEntriesReply_same_lastApplied :
    forall n st src t es b st' l,
      handleAppendEntriesReply n st src t es b = (st', l) ->
      lastApplied st' = lastApplied st.
  Proof.
    intros.
    unfold handleAppendEntriesReply in *.
    repeat (break_match; repeat (find_inversion; simpl in *)); auto using advanceCurrentTerm_same_lastApplied.
  Qed.

  Lemma handleAppendEntries_same_lastApplied :
    forall h st t n pli plt es ci st' ps,
      handleAppendEntries h st t n pli plt es ci = (st', ps) ->
      lastApplied st' = lastApplied st.
  Proof.
    intros.
    unfold handleAppendEntries in *.
    repeat (break_match; repeat (find_inversion; simpl in *)); auto using advanceCurrentTerm_same_lastApplied.
  Qed.
  
  Definition mEntries p :=
    match p with
      | AppendEntries _ _ _ _ entries _ => Some entries
      | _ => None
    end.

  
  Definition term_of msg :=
    match msg with
      | RequestVote t _ _ _ => Some t
      | RequestVoteReply t _ => Some t
      | AppendEntries t _ _ _ _ _ => Some t
      | AppendEntriesReply t _ _ => Some t
    end.

  Theorem sorted_uniqueIndices :
    forall l,
      sorted l -> uniqueIndices l.
  Proof.
    intros; induction l; simpl; auto.
    - unfold uniqueIndices. simpl. constructor.
    - unfold uniqueIndices in *. simpl in *. intuition. constructor; eauto.
      intuition. do_in_map. find_apply_hyp_hyp. omega.
  Qed.


  Lemma wonElection_length :
    forall l1 l2,
      wonElection l1 = true ->
      length l1 <= length l2 ->
      wonElection l2 = true.
  Proof.
    intros.
    unfold wonElection in *. do_bool.
    omega.
  Qed.

  Lemma wonElection_no_dup_in :
    forall l1 l2,
      wonElection l1 = true ->
      NoDup l1 ->
      (forall x, In x l1 -> In x l2) ->
      wonElection l2 = true.
  Proof.
    intros.
    find_eapply_lem_hyp subset_length;
      eauto using name_eq_dec, wonElection_length.
  Qed.
  
  Lemma wonElection_exists_voter :
    forall l,
      wonElection l = true ->
      exists x,
        In x l.
  Proof.
    unfold wonElection.
    intros.
    destruct l; try discriminate.
    simpl. eauto.
  Qed.

  Fixpoint argmax {A : Type} (f : A -> nat) (l : list A) : option A :=
    match l with
      | a :: l' => match argmax f l' with
                    | Some a' => if f a' <=? f a then
                                  Some a
                                else
                                  Some a'
                    | None => Some a
                  end
      | [] => None
    end.

  Lemma argmax_fun_ext :
    forall A (f : A -> nat) g l,
      (forall a, f a = g a) ->
      argmax f l = argmax g l.
  Proof.
    intros. induction l; simpl in *; intuition.
    find_rewrite. break_match; intuition.
    repeat find_higher_order_rewrite. auto.
  Qed.

  Lemma argmax_None :
    forall A (f : A -> nat) l,
      argmax f l = None ->
      l = [].
  Proof.
    intros. destruct l; simpl in *; intuition.
    repeat break_match; congruence.
  Qed.

  Lemma argmax_elim :
    forall A (f : A -> nat) l a,
      argmax f l = Some a ->
      (In a l /\
       forall x, In x l -> f a >= f x).
  Proof.
    induction l; intros; simpl in *; [congruence|].
    repeat break_match; find_inversion.
    - do_bool.
      match goal with
        | H : forall _, Some ?a = Some _ -> _ |- _ =>
          specialize (H a)
      end. intuition; subst; auto.
      find_apply_hyp_hyp. omega.
    - do_bool.
      match goal with
        | H : forall _, Some ?a = Some _ -> _ |- _ =>
          specialize (H a)
      end. intuition; subst; auto.
      find_apply_hyp_hyp. omega.
    - intuition; subst; auto.
      find_apply_lem_hyp argmax_None.
      subst. solve_by_inversion.
  Qed.

  Lemma argmax_in :
    forall A (f : A -> nat) l a,
      argmax f l = Some a ->
      In a l.
  Proof.
    intros. find_apply_lem_hyp argmax_elim. intuition.
  Qed.
  
  Lemma argmax_one_different :
    forall A (A_eq_dec : forall x y : A, {x = y} + {x <> y}) f g (l : list A) a,
      (forall x, In x l -> a <> x -> f x = g x) ->
      (forall x, In x l -> f x <= g x) ->
      (argmax g l = argmax f l \/
       argmax g l = Some a).
  Proof.
    intros. induction l; simpl in *; intuition.
    conclude IHl intuition.
    conclude IHl intuition. intuition.
    - find_rewrite. break_match; intuition.
      repeat break_if; intuition.
      + do_bool. right.
        find_apply_lem_hyp argmax_in; intuition.
        destruct (A_eq_dec a a1); destruct (A_eq_dec a a0); repeat subst; intuition;
        specialize (H0 a1); specialize (H a0); intuition; repeat find_rewrite; omega.
      + do_bool. right.
        find_apply_lem_hyp argmax_in; intuition.
        destruct (A_eq_dec a a1); destruct (A_eq_dec a a0); repeat subst; intuition.
        * specialize (H a1); specialize (H0 a0); intuition. repeat find_rewrite. omega.
        * specialize (H a1); specialize (H0 a0); intuition. repeat find_rewrite. omega.
    - find_rewrite. repeat break_match; subst; intuition.
      do_bool.
      repeat find_apply_lem_hyp argmax_elim; intuition.
      destruct (A_eq_dec a a1); destruct (A_eq_dec a a0); repeat subst; intuition.
      + specialize (H a0); specialize (H0 a1); intuition. repeat find_rewrite. omega.
      + pose proof H a0; pose proof H a1; intuition. repeat find_rewrite.
        specialize (H3 a1). intuition. omega.
  Qed.
  

  Definition applied_entries (sigma : name -> raft_data) : (list entry) :=
    match argmax (fun h => lastApplied (sigma h)) (all_fin N) with
      | Some h =>
        rev (removeAfterIndex (log (sigma h)) (lastApplied (sigma h)))
      | None => []
    end.

  Ltac update_destruct :=
    match goal with
    | [ |- context [ update _ ?y _ ?x ] ] => destruct (name_eq_dec y x)
    end.

  Ltac update_destruct_hyp :=
    match goal with
    | [ _ : context [ update _ ?y _ ?x ] |- _ ] => destruct (name_eq_dec y x)
    end.

  
  Lemma applied_entries_update :
    forall sigma h st,
      lastApplied st >= lastApplied (sigma h) ->
      (applied_entries (update sigma h st) = applied_entries sigma /\
       (exists h', 
          argmax (fun h => lastApplied (sigma h)) (all_fin N) = Some h' /\
          lastApplied (sigma h') >= lastApplied st))
      \/
      (argmax (fun h' => lastApplied (update sigma h st h')) (all_fin N) = Some h /\
       applied_entries (update sigma h st) = (rev (removeAfterIndex (log st) (lastApplied st)))).
  Proof.
    intros.
    unfold applied_entries in *.
    repeat break_match; intuition;
    try solve [find_apply_lem_hyp argmax_None;
                exfalso;
                pose proof (all_fin_all _ h); find_rewrite; intuition].
    match goal with
      | _ : argmax ?f ?l = _, _ : argmax ?g ?l = _ |- _ =>
        pose proof argmax_one_different name name_eq_dec g f l h as Hproof
    end.
    forward Hproof; [intros; rewrite_update; intuition|]; concludes.
    forward Hproof; [intros; update_destruct; subst; rewrite_update; intuition|]; concludes.
    intuition.
    - repeat find_rewrite. find_inversion.
      update_destruct; subst; rewrite_update; intuition. left.
      intuition. eexists; intuition eauto. repeat find_apply_lem_hyp argmax_elim; intuition eauto.
      match goal with
          H : _ |- _ =>
          solve [specialize (H h); rewrite_update; eauto using all_fin_all]
      end.
    - repeat find_rewrite. find_inversion. rewrite_update. intuition.
  Qed.

  Lemma applied_entries_safe_update :
    forall sigma h st,
      lastApplied st = lastApplied (sigma h) ->
      removeAfterIndex (log st) (lastApplied (sigma h))
      = removeAfterIndex (log (sigma h)) (lastApplied (sigma h)) ->
      applied_entries (update sigma h st) = applied_entries sigma.
  Proof.
    intros. unfold applied_entries in *.
    repeat break_match; repeat find_rewrite; intuition;
    match goal with
      | _ : argmax ?f ?l = _, _ : argmax ?g ?l = _ |- _ =>
        assert (argmax f l = argmax g l) by
            (apply argmax_fun_ext; intros; update_destruct; subst; rewrite_update; auto)
    end; repeat find_rewrite; try congruence.
    match goal with | H : Some _ = Some _ |- _ => inversion H end.
    subst. clean.
    f_equal. update_destruct; subst; rewrite_update; repeat find_rewrite; auto.
  Qed.
    
    
  Lemma applied_entries_log_lastApplied_same :
    forall sigma sigma',
      (forall h, log (sigma' h) = log (sigma h)) ->
      (forall h, lastApplied (sigma' h) = lastApplied (sigma h)) ->
      applied_entries sigma' = applied_entries sigma.
  Proof.
    intros.
    unfold applied_entries in *.
    rewrite argmax_fun_ext with (g := fun h : name => lastApplied (sigma h)); intuition.
    break_match; auto.
    repeat find_higher_order_rewrite. auto.
  Qed.

  Lemma applied_entries_log_lastApplied_update_same :
    forall sigma h st,
      log st = log (sigma h) ->
      lastApplied st = lastApplied (sigma h) ->
      applied_entries (update sigma h st) = applied_entries sigma.
  Proof.
    intros.
    apply applied_entries_log_lastApplied_same;
      intros; update_destruct; subst; rewrite_update; auto.
  Qed.

  Lemma applied_entries_cases :
    forall sigma,
      applied_entries sigma = [] \/
      exists h,
        applied_entries sigma = rev (removeAfterIndex (log (sigma h)) (lastApplied (sigma h))).
  Proof.
    intros.
    unfold applied_entries in *.
    break_match; simpl in *; intuition eauto.
  Qed.

  Lemma removeAfterIndex_partition :
    forall l x,
      exists l',
        l = l' ++ removeAfterIndex l x.
  Proof.
    intros; induction l; simpl in *; intuition eauto using app_nil_r.
    break_exists. break_if; [exists nil; eauto|].
    do_bool.
    match goal with
      | l : list entry, e : entry |- _ =>
        solve [exists (e :: l); simpl in *; f_equal; auto]
    end.
  Qed.
  

  Lemma doLeader_appliedEntries :
  forall sigma h os st' ms,
    doLeader (sigma h) h = (os, st', ms) ->
    applied_entries (update sigma h st') = applied_entries sigma.
  Proof.
    intros.
    apply applied_entries_log_lastApplied_same.
    - intros. update_destruct; subst; rewrite_update; auto.
      eapply doLeader_same_log; eauto.
    - intros. update_destruct; subst; rewrite_update; auto.
      unfold doLeader in *. repeat break_match; find_inversion; auto.
  Qed.

  Lemma applyEntries_spec :
    forall es h st os st',
      applyEntries h st es = (os, st') ->
      exists d cc,
        st' = {[ {[ st with stateMachine := d ]} with clientCache := cc ]}.
  Proof.
    induction es; intros; simpl in *; intuition.
    - find_inversion. destruct st'; repeat eexists; eauto.
    - unfold applyEntry in *.
      repeat break_match; repeat find_inversion;
      find_apply_hyp_hyp; break_exists; repeat eexists; eauto.
  Qed.

    
End CommonTheorems.

Notation is_append_entries m :=
  (exists t n prevT prevI entries c,
     m = AppendEntries t n prevT prevI entries c).

Notation is_request_vote_reply m :=
  (exists t r,
     m = RequestVoteReply t r).

Ltac use_applyEntries_spec :=
  match goal with
    | H : context [applyEntries] |- _ => eapply applyEntries_spec in H; eauto; break_exists
  end.
