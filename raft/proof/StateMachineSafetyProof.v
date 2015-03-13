Require Import List.

Require Import VerdiTactics.
Require Import Util.
Require Import Net.

Require Import CommonTheorems.
Require Import Raft.
Require Import RaftRefinementInterface.
Require Import StateMachineSafetyInterface.
Require Import CommitRecordedCommittedInterface.
Require Import LeaderCompletenessInterface.
Require Import AllEntriesLeaderLogsInterface.
Require Import LogMatchingInterface.
Require Import UniqueIndicesInterface.

Section StateMachineSafetyProof.
  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Context {rri : raft_refinement_interface}.
  Context {crci : commit_recorded_committed_interface}.
  Context {lci : leader_completeness_interface}.
  Context {aelli : all_entries_leader_logs_interface}.
  Context {lmi : log_matching_interface}.
  Context {uii : unique_indices_interface}.
  
  Definition lifted_state_machine_safety (net : network) : Prop :=
    state_machine_safety (deghost net).

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
  
  Theorem state_machine_safety_host_invariant :
    forall net,
      refined_raft_intermediate_reachable net ->
      state_machine_safety_host (deghost net).
  Proof.
    unfold state_machine_safety_host. intros.
    find_apply_lem_hyp commit_recorded_committed_invariant; auto.
    find_apply_lem_hyp commit_recorded_committed_invariant; auto.
    unfold commit_recorded_committed in *.
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
      
  Theorem state_machine_safety_invariant :
    forall net,
      raft_intermediate_reachable net ->
      state_machine_safety net.
  Proof.
    apply lower_prop.
    intros.
    unfold state_machine_safety. split.
    - auto using state_machine_safety_host_invariant.
    - admit.
  Qed.

  Instance smsi : state_machine_safety_interface.
  Proof.
    split.
    exact state_machine_safety_invariant.
  Qed.
End StateMachineSafetyProof.
