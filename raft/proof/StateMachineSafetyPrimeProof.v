Require Import List.
Require Import Omega.

Require Import VerdiTactics.
Require Import Util.
Require Import Net.

Require Import CommonTheorems.
Require Import Raft.
Require Import SortedInterface.
Require Import RaftRefinementInterface.
Require Import StateMachineSafetyPrimeInterface.
Require Import CommitRecordedCommittedInterface.
Require Import LeaderCompletenessInterface.
Require Import LeaderLogsContiguousInterface.
Require Import AllEntriesLeaderLogsInterface.
Require Import LogMatchingInterface.
Require Import UniqueIndicesInterface.
Require Import AppendEntriesRequestLeaderLogsInterface.
Require Import LeaderLogsSortedInterface.
Require Import LeaderLogsLogMatchingInterface.
Require Import SpecLemmas.

Require Import UpdateLemmas.
Local Arguments update {_} {_} {_} _ _ _ _ : simpl never.

Section StateMachineSafety'.
  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Context {rri : raft_refinement_interface}.
  Context {crci : commit_recorded_committed_interface}.
  Context {lci : leader_completeness_interface}.
  Context {aelli : all_entries_leader_logs_interface}.
  Context {lmi : log_matching_interface}.
  Context {uii : unique_indices_interface}.
  Context {aerlli : append_entries_leaderLogs_interface}.
  Context {llsi : leaderLogs_sorted_interface}.
  Context {lsi : sorted_interface}.
  Context {llci : leaderLogs_contiguous_interface}.
  Context {lllmi : leaderLogs_entries_match_interface}.

  Theorem lift_log_matching :
    forall net,
      refined_raft_intermediate_reachable net ->
      log_matching (deghost net).
  Proof.
    intros.
    eapply lift_prop; eauto using log_matching_invariant.
  Qed.

  Theorem lift_entries_match :
    forall net h h',
      refined_raft_intermediate_reachable net ->
      entries_match (log (snd (nwState net h))) (log (snd (nwState net h'))).
  Proof.
    intros.
    find_apply_lem_hyp lift_log_matching.
    unfold log_matching, log_matching_hosts in *. intuition.
    unfold deghost in *. simpl in *.
    repeat break_match; eauto.
  Qed.

  Theorem lift_UniqueIndices :
    forall net,
      refined_raft_intermediate_reachable net ->
      UniqueIndices (deghost net).
  Proof.
    intros. eapply lift_prop; eauto using UniqueIndices_invariant.
  Qed.

  Theorem lift_uniqueIndices_log :
    forall net h,
      refined_raft_intermediate_reachable net ->
      uniqueIndices (log (snd (nwState net h))).
  Proof.
    intros.
    find_apply_lem_hyp lift_UniqueIndices.
    unfold UniqueIndices, uniqueIndices_host_invariant in *.
    intuition.
    unfold deghost in *. simpl in *. break_match; eauto.
  Qed.
  
  Theorem state_machine_safety_host'_invariant :
    forall net,
      refined_raft_intermediate_reachable net ->
      state_machine_safety_host' net.
  Proof.
    unfold state_machine_safety_host'. intros.
    find_copy_apply_lem_hyp leader_completeness_invariant.
    unfold leader_completeness in *. intuition.
    unfold committed in *. break_exists. intuition.
    repeat match goal with
             | [ H : directly_committed _ ?e |- _ ] =>
               try match goal with
                     | H' : context [ allEntries ] |- _ =>
                       match type of H' with
                         | context [ e ] => fail 3
                       end
                   end;
                 let Hnew := fresh "H" in
                 remember H as Hnew; unfold directly_committed in Hnew;
                 match goal with
                   | [ Heq : Hnew = H |- _ ] => clear Heq
                 end
           end.
    break_exists. intuition.
    assert (NoDup nodes) by eauto using all_fin_NoDup.
    match goal with
      | H : NoDup nodes, _ : NoDup ?l1, _ : NoDup ?l2 |- _ =>
        eapply pigeon with (l := nodes) (sub1 := l1) (sub2 := l2) in H
    end; eauto using all_fin_all, name_eq_dec, div2_correct.
    break_exists.
    intuition.
    repeat find_apply_hyp_hyp.
    do 2 find_apply_lem_hyp all_entries_leader_logs_invariant; auto.
    intuition; try solve [break_exists; intuition; find_false; eauto].
    match goal with
      | [ _ : eIndex ?e <= eIndex ?x, _ : eIndex ?e' <= eIndex ?x',
          _ : In ?x ?l |- ?e = ?e' ] =>
        cut (In e l /\ In e' l)
    end;
      [intros; intuition;
       eapply uniqueIndices_elim_eq;
       eauto using lift_uniqueIndices_log|].
    intuition;
      match goal with
        | _ : In ?e ?l, _ : eIndex ?e <= eIndex ?x, _ : In ?x ?l' |- In ?e ?l' =>
          assert (entries_match l l') as Hem by eauto using lift_entries_match;
            specialize (Hem x x e)
      end; intuition.
  Qed.


  Ltac copy_eapply_prop_hyp P Q :=
    match goal with
      | [ H : context [ P ], H' : context [ Q ] |- _ ] =>
        copy_eapply H H'
    end.

  Lemma contiguous_app :
    forall l1 l2 i,
      sorted (l1 ++ l2) ->
      contiguous_range_exact_lo (l1 ++ l2) i ->
      contiguous_range_exact_lo l2 i.
  Proof.
  Admitted.

  Lemma prefix_contiguous :
    forall l l' e i,
      Prefix l' l ->
      sorted l ->
      In e l ->
      eIndex e > i ->
      contiguous_range_exact_lo l' i ->
      In e l'.
  Proof.
  Admitted.

  Lemma entries_contiguous :
    forall net p t n pli plt es ci,
      refined_raft_intermediate_reachable net ->
      In p (nwPackets net) ->
      pBody p = AppendEntries t n pli plt es ci ->
      contiguous_range_exact_lo es pli.
  Proof. (* by log matching, annoying because of refinement *)
  Admitted.

  Lemma entries_sorted :
    forall net p t n pli plt es ci,
      refined_raft_intermediate_reachable net ->
      In p (nwPackets net) ->
      pBody p = AppendEntries t n pli plt es ci ->
      sorted es.
  Proof. (* by log matching, annoying because of refinement *)
  Admitted.
  
  Ltac get_invariant i :=
    match goal with
      | H : refined_raft_intermediate_reachable _ |- _ =>
        copy_apply i H
    end.
  
  Theorem state_machine_safety_nw'_invariant :
    forall net,
      refined_raft_intermediate_reachable net ->
      state_machine_safety_nw' net.
  Proof.
    unfold state_machine_safety_nw'.
    intros.
    unfold committed in *. break_exists; intuition.
    assert (t > eTerm x0 \/ eTerm x0 = t) by admit. intuition.
    - find_copy_apply_lem_hyp append_entries_leaderLogs_invariant.
      copy_eapply_prop_hyp append_entries_leaderLogs AppendEntries; eauto.
      break_exists; break_and.
      get_invariant leader_completeness_invariant.
      get_invariant leaderLogs_sorted_invariant.
      unfold leaderLogs_sorted in *.
      unfold leader_completeness in *. break_and.
      eapply_prop_hyp leader_completeness_directly_committed directly_committed; eauto.
      repeat conclude_using eauto.
      get_invariant leaderLogs_entries_match_invariant.
      unfold leaderLogs_entries_match_host in *.
      match goal with
        | _ : In _ (log (snd (nwState _ ?x))),
              H : In _ (leaderLogs _),
                  H' : context [ entries_match ] |- _ =>
          let H'' := fresh "H" in
          pose proof H as H'';
          eapply H' with (h := x) in H''
      end.
      match goal with
        | [ _ : In ?e ?l,
            _ : In ?e' ?l,
            _ : In ?e' ?l',
            H : entries_match _ _ |- _ ] =>    
          specialize(H e' e' e)
      end; repeat concludes.
      match goal with
        | _ : ?P <-> ?Q, _ : ?P |- _ =>
          assert Q by intuition
      end.
      intuition.
      + left.
        eapply gt_le_trans; eauto.
        eapply maxIndex_is_max; eauto.
      + break_exists. intuition. subst.
        match goal with
          | |- context [eIndex ?x > eIndex ?e ] =>
            destruct (Compare_dec.lt_eq_lt_dec (eIndex x) (eIndex e))
        end; intuition.
        * right. right. right.
          apply in_app_iff. right.
          eapply prefix_contiguous; eauto.
          find_copy_eapply_lem_hyp entries_contiguous; eauto.
          eapply contiguous_app; eauto using entries_sorted.
        * cut (e = x5); [intros; subst; intuition|].
          eapply uniqueIndices_elim_eq; eauto using sorted_uniqueIndices.
      + subst. right. right. right.
        apply in_app_iff. right.
        get_invariant leaderLogs_contiguous_invariant.
        unfold leaderLogs_contiguous in *. find_copy_apply_hyp_hyp.
        eapply prefix_contiguous with (i := 0); eauto;
        [match goal with
           | _ : In (_, ?l) (leaderLogs _), H : contiguous_range_exact_lo ?l _ |- _ =>
             unfold contiguous_range_exact_lo in H; intuition
         end
        |]; [idtac].
        find_copy_eapply_lem_hyp entries_contiguous; eauto.
        eapply contiguous_app; eauto using entries_sorted.
    - admit.
  Qed.

  Instance sms'i : state_machine_safety'interface.
  Proof.
    split.
    intuition.
    split.
    - auto using state_machine_safety_host'_invariant.
    - auto using state_machine_safety_nw'_invariant.
  Qed.
End StateMachineSafety'.
