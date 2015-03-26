Require Import List.
Import ListNotations.
Require Import Omega.

Require Import VerdiTactics.
Require Import Util.
Require Import Net.
Require Import Raft.
Require Import RaftRefinementInterface.

Require Import CommonDefinitions.
Require Import CommonTheorems.

Require Import SpecLemmas.

Require Import UpdateLemmas.
Local Arguments update {_} {_} {_} _ _ _ _ : simpl never.

Require Import LogMatchingInterface.
Require Import LeaderLogsTermSanityInterface.
Require Import LeaderLogsSortedInterface.
Require Import SortedInterface.
Require Import LeaderLogsSublogInterface.
Require Import AllEntriesLeaderLogsInterface.
Require Import LeaderLogsContiguousInterface.

Require Import LeaderLogsLogMatchingInterface.

Section LeaderLogsLogMatching.

  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Context {rri : raft_refinement_interface}.
  Context {lmi : log_matching_interface}.
  Context {lltsi : leaderLogs_term_sanity_interface}.
  Context {llsi : leaderLogs_sorted_interface}.
  Context {si : sorted_interface}.
  Context {aelli : all_entries_leader_logs_interface}.
  Context {llsli : leaderLogs_sublog_interface}.
  Context {llci : leaderLogs_contiguous_interface}.

  Definition leaderLogs_entries_match_nw (net : network) : Prop :=
    forall h llt ll p t src pli plt es ci,
      In (llt, ll) (leaderLogs (fst (nwState net h))) ->
      In p (nwPackets net) ->
      pBody p = AppendEntries t src pli plt es ci ->
      (forall e1 e2,
         eIndex e1 = eIndex e2 ->
         eTerm e1 = eTerm e2 ->
         In e1 es ->
         In e2 ll ->
         (forall e3,
            eIndex e3 <= eIndex e1 ->
            In e3 es ->
            In e3 ll) /\
         (pli <> 0 ->
          exists e4,
            eIndex e4 = pli /\
            eTerm e4 = plt /\
            In e4 ll)).

  Definition leaderLogs_entries_match (net : network) : Prop :=
    leaderLogs_entries_match_host net /\
    leaderLogs_entries_match_nw net.

  Lemma leaderLogs_entries_match_init :
    refined_raft_net_invariant_init leaderLogs_entries_match.
  Proof.
    unfold refined_raft_net_invariant_init, leaderLogs_entries_match,
           leaderLogs_entries_match_host, leaderLogs_entries_match_nw.
    simpl.
    intuition.
  Qed.

  Ltac update_destruct :=
    match goal with
      | [ H : context [ update _ ?x _ ?y ] |- _ ] =>
        destruct (name_eq_dec x y); subst; rewrite_update; simpl in *
      | [ |- context [ update _ ?x _ ?y ] ] =>
        destruct (name_eq_dec x y); subst; rewrite_update; simpl in *
    end.

  Lemma update_elections_data_client_request_leaderLogs :
    forall h st client id c,
      leaderLogs (update_elections_data_client_request h st client id c) =
      leaderLogs (fst st).
  Proof.
    unfold update_elections_data_client_request in *.
    intros. repeat break_match; repeat find_inversion; auto.
  Qed.

  Lemma entries_match_cons_gt_maxTerm :
    forall x xs ys,
      sorted xs ->
      sorted ys ->
      eIndex x > maxIndex xs ->
      eTerm x > maxTerm ys ->
      entries_match xs ys ->
      entries_match (x :: xs) ys.
  Proof.
    unfold entries_match.
    intuition; simpl in *; intuition; subst; subst;
    try match goal with
        | [ H : In _ _ |- _ ] => apply maxTerm_is_max in H; [| solve[auto]]; omega
        | [ H : In _ _ |- _ ] => apply maxIndex_is_max in H; [| solve[auto]]; omega
      end.
    - match goal with
        | [ H : _ |- _ ] => solve [eapply H; eauto]
      end.
    - right. match goal with
        | [ H : _ |- _ ] => solve [eapply H; eauto]
      end.
  Qed.

  Lemma entries_match_cons_sublog :
    forall x xs ys,
      sorted xs ->
      sorted ys ->
      eIndex x > maxIndex xs ->
      entries_match xs ys ->
      (forall y, In y ys -> eTerm x = eTerm y -> In y xs) ->
      entries_match (x :: xs) ys.
  Proof.
    unfold entries_match.
    intuition; simpl in *; intuition; subst; subst;
    try solve [
         exfalso; try find_apply_hyp_hyp;
          match goal with
            | [ H : In _ _ |- _ ] => apply maxIndex_is_max in H; [| solve[auto]]; omega
          end].
    - match goal with
        | [ H : _ |- _ ] => solve [eapply H; eauto]
      end.
    - right. match goal with
        | [ H : _ |- _ ] => solve [eapply H; eauto]
      end.
  Qed.

  Lemma entries_match_nil :
    forall l,
      entries_match l [].
  Proof.
    red.
    simpl.
    intuition.
  Qed.

  Lemma lifted_logs_sorted_nw :
    forall net p t n plt plti es ci,
      refined_raft_intermediate_reachable net ->
      In p (nwPackets net) ->
      pBody p = AppendEntries t n plt plti es ci ->
      sorted es.
  Proof.
    intros.
    pose proof (lift_prop _ logs_sorted_invariant).
    find_insterU. conclude_using eauto.
    unfold logs_sorted in *. break_and.
    unfold logs_sorted_nw in *.
    eapply H3.
    - unfold deghost. simpl.
      apply in_map_iff. eauto.
    - simpl. eauto.
  Qed.

  Lemma lifted_logs_sorted_host :
    forall net h ,
      refined_raft_intermediate_reachable net ->
      sorted (log (snd (nwState net h))).
  Proof.
    intros.
    pose proof (lift_prop _ logs_sorted_invariant).
    find_insterU. conclude_using eauto.
    unfold logs_sorted in *. break_and.
    unfold logs_sorted_host in *.
    find_insterU.
    find_rewrite_lem deghost_spec.
    eauto.
  Qed.

  Lemma leaderLogs_entries_match_nw_packet_set :
    forall net net',
      (forall p, In p (nwPackets net') ->
                 is_append_entries (pBody p) ->
                 In p (nwPackets net)) ->
      (forall h, leaderLogs (fst (nwState net' h)) = leaderLogs (fst (nwState net h))) ->
      leaderLogs_entries_match_nw net ->
      leaderLogs_entries_match_nw net'.
  Proof.
    unfold leaderLogs_entries_match_nw.
    intros.
    eapply_prop_hyp In nwPackets; [|eauto 10].
    eapply H1; eauto.
    repeat find_higher_order_rewrite.
    eauto.
  Qed.

  Lemma handleClientRequest_no_send :
    forall h st client id c out st' ms,
      handleClientRequest h st client id c = (out, st', ms) ->
      ms = [].
  Proof.
    unfold handleClientRequest.
    intros.
    repeat break_match; repeat find_inversion; auto.
  Qed.

  Lemma leaderLogs_entries_match_client_request :
    refined_raft_net_invariant_client_request leaderLogs_entries_match.
  Proof.
    unfold refined_raft_net_invariant_client_request, leaderLogs_entries_match.
    intros.
    split.
    - { unfold leaderLogs_entries_match_host.
        simpl. intuition. subst. find_higher_order_rewrite.
        repeat update_destruct.
        - rewrite update_elections_data_client_request_leaderLogs in *.
          destruct (log d) using (handleClientRequest_log_ind $(eauto)$).
          + eauto.
          + destruct ll.
            * apply entries_match_nil.
            * { apply entries_match_cons_gt_maxTerm; eauto.
                - eauto using lifted_logs_sorted_host.
                - eapply leaderLogs_sorted_invariant; eauto.
                - omega.
                - find_copy_apply_lem_hyp leaderLogs_currentTerm_invariant; auto.
                  find_copy_apply_lem_hyp leaderLogs_term_sanity_invariant.
                  unfold leaderLogs_term_sanity in *.
                  eapply_prop_hyp In In; simpl; eauto. repeat find_rewrite.
                  simpl in *. omega.
              }
        - rewrite update_elections_data_client_request_leaderLogs in *.
          eauto.
        - destruct (log d) using (handleClientRequest_log_ind $(eauto)$).
          + eauto.
          + apply entries_match_cons_sublog; eauto.
            * eauto using lifted_logs_sorted_host.
            * eapply leaderLogs_sorted_invariant; eauto.
            * omega.
            * intros.
              eapply leaderLogs_sublog_invariant; eauto.
              simpl in *. congruence.
        - eauto.
      }
    - eapply leaderLogs_entries_match_nw_packet_set with (net:=net); intuition.
      + find_apply_hyp_hyp. intuition eauto.
        erewrite handleClientRequest_no_send with (ms := l) in * by eauto.
        simpl in *. intuition.
      + simpl. subst. find_higher_order_rewrite.
        rewrite update_fun_comm. simpl.
        rewrite update_fun_comm. simpl.
        rewrite update_elections_data_client_request_leaderLogs.
        now rewrite update_nop_ext' by auto.
  Qed.

  Lemma update_elections_data_timeout_leaderLogs :
    forall h st,
      leaderLogs (update_elections_data_timeout h st) = leaderLogs (fst st).
  Proof.
    unfold update_elections_data_timeout.
    intros.
    repeat break_match; auto.
  Qed.

  Lemma leaderLogs_entries_match_timeout :
    refined_raft_net_invariant_timeout leaderLogs_entries_match.
  Proof.
    unfold refined_raft_net_invariant_timeout, leaderLogs_entries_match.
    intuition.
    - unfold leaderLogs_entries_match_host in *.
      intros. simpl in *. repeat find_higher_order_rewrite.
      repeat update_destruct; rewrite_update;
      try rewrite update_elections_data_timeout_leaderLogs in *;
      try erewrite handleTimeout_log_same by eauto; eauto.
    - eapply leaderLogs_entries_match_nw_packet_set with (net:=net); intuition.
      + simpl in *. find_apply_hyp_hyp.  intuition.
        do_in_map. subst. simpl in *.
        exfalso. eapply handleTimeout_not_is_append_entries; eauto 10.
      + simpl. repeat find_higher_order_rewrite.
        rewrite update_fun_comm. simpl.
        rewrite update_fun_comm. simpl.
        rewrite update_elections_data_timeout_leaderLogs.
        rewrite update_nop_ext'; auto.
  Qed.

  Lemma update_elections_data_appendEntries_leaderLogs :
    forall h st t src pli plt es ci,
      leaderLogs (update_elections_data_appendEntries h st t src pli plt es ci) = leaderLogs (fst st).
  Proof.
    unfold update_elections_data_appendEntries.
    intros. repeat break_match; auto.
  Qed.

  Lemma leaderLogs_entries_match_append_entries :
    refined_raft_net_invariant_append_entries leaderLogs_entries_match.
  Proof.
    unfold refined_raft_net_invariant_append_entries, leaderLogs_entries_match.
    intuition.
    - unfold leaderLogs_entries_match_host in *. intros.
      {
        intros. simpl in *. repeat find_higher_order_rewrite.
        find_rewrite_lem update_fun_comm. simpl in *.
        find_rewrite_lem update_fun_comm.
        rewrite update_elections_data_appendEntries_leaderLogs in *.
        find_erewrite_lem update_nop_ext'.
        update_destruct; rewrite_update;
        try rewrite update_elections_data_appendEntries_leaderLogs in *; eauto.
        destruct (log d) using (handleAppendEntries_log_ind $(eauto)$); eauto.
        + eapply entries_match_scratch with (plt0 := plt).
          * eauto using lifted_logs_sorted_nw.
          * apply sorted_uniqueIndices.
            eapply leaderLogs_sorted_invariant; eauto.
          * subst. eapply_prop leaderLogs_entries_match_nw; eauto.
          * admit.
          * admit.
          * admit.
        + eapply entries_match_append; eauto.
          * admit.
          * admit.
          * admit.
          * admit.
          * admit.
          * eapply findAtIndex_intro; eauto using lifted_logs_sorted_host, sorted_uniqueIndices.
      }
    - (* nw *) admit.
  Qed.

  Lemma leaderLogs_entries_match_append_entries_reply :
    refined_raft_net_invariant_append_entries_reply leaderLogs_entries_match.
  Admitted.

  Lemma leaderLogs_entries_match_request_vote :
    refined_raft_net_invariant_request_vote leaderLogs_entries_match.
  Admitted.

  Lemma leaderLogs_entries_match_request_vote_reply :
    refined_raft_net_invariant_request_vote_reply leaderLogs_entries_match.
  Admitted.

  Lemma leaderLogs_entries_match_do_leader :
    refined_raft_net_invariant_do_leader leaderLogs_entries_match.
  Admitted.

  Lemma leaderLogs_entries_match_do_generic_server :
    refined_raft_net_invariant_do_generic_server leaderLogs_entries_match.
  Admitted.

  Lemma leaderLogs_entries_match_state_same_packet_subset :
    refined_raft_net_invariant_state_same_packet_subset leaderLogs_entries_match.
  Admitted.

  Lemma leaderLogs_entries_match_reboot :
    refined_raft_net_invariant_reboot leaderLogs_entries_match.
  Admitted.

  Lemma leaderLogs_entries_match_invariant :
    forall net,
      refined_raft_intermediate_reachable net ->
      leaderLogs_entries_match net.
  Proof.
    intros.
    apply refined_raft_net_invariant; auto.
    - apply leaderLogs_entries_match_init.
    - apply leaderLogs_entries_match_client_request.
    - apply leaderLogs_entries_match_timeout.
    - apply leaderLogs_entries_match_append_entries.
    - apply leaderLogs_entries_match_append_entries_reply.
    - apply leaderLogs_entries_match_request_vote.
    - apply leaderLogs_entries_match_request_vote_reply.
    - apply leaderLogs_entries_match_do_leader.
    - apply leaderLogs_entries_match_do_generic_server.
    - apply leaderLogs_entries_match_state_same_packet_subset.
    - apply leaderLogs_entries_match_reboot.
  Qed.

  Instance lllmi : leaderLogs_entries_match_interface : Prop.
  Proof.
    split.
    apply leaderLogs_entries_match_invariant.
  Qed.
End LeaderLogsLogMatching.
