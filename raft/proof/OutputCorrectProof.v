Require Import List.
Import ListNotations.
Require Import Arith.
Require Import Nat.
Require Import Omega.

Require Import Net.
Require Import Util.
Require Import VerdiTactics.
Require Import TraceRelations.

Require Import Raft.
Require Import CommonTheorems.
Require Import OutputCorrectInterface.
Require Import AppliedEntriesMonotonicInterface.
Require Import TraceUtil.

Require Import StateMachineCorrectInterface.

Require Import UpdateLemmas.
Local Arguments update {_} {_} {_} _ _ _ _ : simpl never.

Section OutputCorrect.
  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Context {aemi : applied_entries_monotonic_interface}.
  Context {smci : state_machine_correct_interface}.

  Section inner.
  Variables client id : nat.
  Variable out : output.
  
  Theorem in_output_trace_dec :
    forall tr : list (name * (raft_input + list raft_output)),
      {in_output_trace client id out tr} + {~ in_output_trace client id out tr}.
  Proof.
    unfold in_output_trace.
    intros.
    destruct (find (fun p => match snd p with
                               | inr l => match find (is_client_response client id out) l with
                                            | Some x => true
                                            | None => false
                                          end
                               | _ => false
                             end) tr) eqn:?.
    - find_apply_lem_hyp find_some. break_and.
      repeat break_match; try discriminate.
      find_apply_lem_hyp find_some. break_and.
      unfold is_client_response, in_output_list in *.
      break_match; try discriminate. do_bool. break_and. do_bool. subst.
      left. exists l, (fst p). clean.
      break_and. do_bool.
      break_if; try congruence. subst. intuition.
      find_reverse_rewrite.
      rewrite <- surjective_pairing.
      auto.
    - right. intro. break_exists. break_and.
      find_eapply_lem_hyp find_none; eauto.
      simpl in *. break_match; try discriminate.
      unfold in_output_list in *. break_exists.
      find_eapply_lem_hyp find_none; eauto.
      simpl in *. find_apply_lem_hyp Bool.andb_false_elim.
      repeat (intuition; do_bool).
      break_if; congruence.
  Qed.

  Lemma in_output_changed :
    forall tr o,
      ~ in_output_trace client id out tr ->
      in_output_trace client id out (tr ++ o) ->
      in_output_trace client id out o.
  Proof.
    intros. unfold in_output_trace in *.
    break_exists_exists.
    intuition. do_in_app; intuition.
    exfalso. eauto.
  Qed.

  Lemma in_output_list_split :
    forall l l',
      in_output_list client id out (l ++ l') ->
      in_output_list client id out l \/ in_output_list client id out l'.
  Proof.
    intros.
    unfold in_output_list in *.
    break_exists; do_in_app; intuition eauto.
  Qed.

  Lemma in_output_list_empty :
    ~ in_output_list client id out [].
  Proof.
    intuition.
  Qed.

  Lemma doLeader_key_in_output_list :
    forall st h os st' m,
      doLeader st h = (os, st', m) ->
      ~ in_output_list client id out os.
  Proof.
    intros. unfold doLeader, advanceCommitIndex in *.
    repeat break_match; find_inversion; intuition eauto using key_in_output_list_empty.
  Qed.

  Lemma handleInput_key_in_output_list :
    forall st h i os st' m,
      handleInput h i st = (os, st', m) ->
      ~ in_output_list client id out os.
  Proof.
    intros. unfold handleInput, handleTimeout, handleClientRequest, tryToBecomeLeader in *.
    repeat break_match; find_inversion; intuition eauto using in_output_list_empty;
    unfold in_output_list in *; break_exists; simpl in *; intuition; congruence.
  Qed.

  Ltac update_destruct :=
    match goal with
      | [ |- context [ update _ ?y _ ?x ] ] => destruct (name_eq_dec y x)
    end.

  Lemma deduplicate_log'_app :
    forall l l' ks,
      exists l'',
        deduplicate_log' (l ++ l') ks = deduplicate_log' l ks ++ l''.
  Admitted.


  Lemma deduplicate_log_app :
    forall l l',
      exists l'',
        deduplicate_log (l ++ l') = deduplicate_log l ++ l''.
  Proof.
    eauto using deduplicate_log'_app.
  Qed.
  

  Lemma in_output_trace_not_nil :
      in_output_trace client id out [] -> False.
  Proof.
    unfold in_output_trace.
    simpl. intros. break_exists. intuition.
  Qed.

  Lemma in_output_trace_singleton_inv :
    forall h l,
      in_output_trace client id out [(h, inr l)] ->
      in_output_list client id out l.
  Proof.
    unfold in_output_trace.
    intuition.
    break_exists. simpl in *. intuition.
    find_inversion. auto.
  Qed.

  Lemma in_output_list_app_or :
    forall l1 l2,
      in_output_list client id out (l1 ++ l2) ->
      in_output_list client id out l1 \/
      in_output_list client id out l2.
  Proof.
    unfold in_output_list.
    intuition.
  Qed.

  Lemma in_output_trace_inp_inv :
    forall h i tr,
      in_output_trace client id out ((h, inl i) :: tr) ->
      in_output_trace client id out tr.
  Proof.
    unfold in_output_trace.
    intuition. break_exists_exists. simpl in *. intuition.
    find_inversion.
  Qed.

  Lemma in_output_list_not_leader_singleton :
    forall a b,
      ~ in_output_list client id out [NotLeader a b].
  Proof.
    unfold in_output_list. simpl. intuition. discriminate.
  Qed.

  Lemma handleInput_in_output_list :
    forall h i st os st' ms,
      handleInput h i st = (os, st', ms) ->
      ~ in_output_list client id out os.
  Proof.
    unfold handleInput, handleTimeout, handleInput, tryToBecomeLeader, handleClientRequest.
    intuition.
    repeat break_match; repeat find_inversion; eauto using in_output_trace_not_nil.
    - exfalso. eapply in_output_list_not_leader_singleton; eauto.
    - exfalso. eapply in_output_list_not_leader_singleton; eauto.
  Qed.

  Lemma in_output_list_cons_or :
    forall a b c l,
      in_output_list client id out (ClientResponse a b c :: l) ->
      (a = client /\ b = id /\ c = out) \/
      in_output_list client id out l.
  Proof.
    unfold in_output_list.
    simpl. intuition.
    find_inversion. auto.
  Qed.

  Lemma assoc_Some_In :
    forall K V (K_eq_dec : forall k k' : K, {k = k'} + {k <> k'}) k v l,
      assoc (V:=V) K_eq_dec l k = Some v ->
      In (k, v) l.
  Proof.
    induction l; simpl; intros; repeat break_match.
    - discriminate.
    - find_inversion. auto.
    - intuition.
  Qed.

  Lemma getLastId_Some_In :
    forall st c n o,
      getLastId st c = Some (n, o) ->
      In (c, (n, o)) (clientCache st).
  Proof.
    unfold getLastId.
    eauto using assoc_Some_In.
  Qed.

  Lemma middle_app_assoc :
    forall A xs (y : A) zs,
      xs ++ y :: zs = (xs ++ [y]) ++ zs.
  Proof.
    induction xs; intros; simpl; auto using f_equal.
  Qed.

  Lemma cacheApplyEntry_correct :
    forall st e l st' es,
      cacheApplyEntry st e = (l, st') ->
      stateMachine st = snd (execute_log (deduplicate_log es)) ->
      (* some condition on the cache and e... *)
      stateMachine st' = snd (execute_log (deduplicate_log (es ++ [e]))).
  Admitted.

  Lemma applyEntries_output_correct :
    forall l c i o h st os st' es,
      applyEntries h st l = (os, st') ->
      in_output_list c i o os ->
      (stateMachine st = snd (execute_log (deduplicate_log es))) ->
      (forall c i o,
         In (c, (i, o)) (clientCache st) ->
         output_correct c i o es) ->
      output_correct c i o (es ++ l).
  Proof.
    induction l; intros; simpl in *.
    - find_inversion. exfalso. eapply in_output_list_empty; eauto.
    - repeat break_let. find_inversion.
      break_if.
      + admit.
      + rewrite middle_app_assoc. eapply IHl.
        * eauto.
        * auto.
        * eapply cacheApplyEntry_correct; eauto.
        * intros. admit.
  Qed.

  Lemma doGenericServer_output_correct :
    forall h ps sigma os st' ms,
      raft_intermediate_reachable (mkNetwork ps sigma) ->
      doGenericServer h (sigma h) = (os, st', ms) ->
      in_output_list client id out os ->
      output_correct client id out (applied_entries (update sigma h st')).
  Proof.
    intros.
    unfold doGenericServer in *.
    break_let. find_inversion.
    eapply applyEntries_output_correct
           with (es := rev (removeAfterIndex (log (sigma h)) (lastApplied (sigma h)))) in Heqp; eauto.
    - (* something about prefix output_correct *) admit.
    - (* smc *) admit.
    - (* cache correct *) admit.
  Qed.

  Ltac intermediate_networks :=
    match goal with
      | Hdgs : doGenericServer ?h ?st = _,
               Hdl : doLeader ?st' ?h = _ |- context [update (nwState ?net) ?h ?st''] =>
        replace st with (update (nwState net) h st h) in Hdgs by eauto using update_eq;
          replace st' with (update (update (nwState net) h st) h st' h) in Hdl by eauto using update_eq;
          let H := fresh "H" in
          assert (update (nwState net) h st'' =
                  update (update (update (nwState net) h st) h st') h st'') by (repeat rewrite update_overwrite; auto); unfold data in *; simpl in *; rewrite H; clear H
    end.

  Lemma in_output_trace_step_output_correct :
    forall failed failed' (net net' : network (params := @multi_params _ _ raft_params)) os,
      in_output_trace client id out os ->
      @raft_intermediate_reachable _ _ raft_params net ->
      step_f (failed, net) (failed', net') os ->
      output_correct client id out (applied_entries (nwState net')).
  Proof.
    intros.
    match goal with
      | [ H : context [ step_f _ _ _ ] |- _ ] => invcs H
    end.
    - unfold RaftNetHandler in *. repeat break_let. repeat find_inversion.
      find_apply_lem_hyp in_output_trace_singleton_inv.
      find_apply_lem_hyp in_output_list_app_or.
      intuition.
      + intermediate_networks.
        find_apply_lem_hyp doLeader_appliedEntries. find_rewrite.
        eapply doGenericServer_output_correct; eauto.
        eapply RIR_handleMessage; eauto.
      + exfalso. eapply doLeader_key_in_output_list; eauto.
    - unfold RaftInputHandler in *. repeat break_let. repeat find_inversion.
      find_apply_lem_hyp in_output_trace_inp_inv.
      find_apply_lem_hyp in_output_trace_singleton_inv.
      find_apply_lem_hyp in_output_list_app_or.
      intuition.
      + exfalso. eapply handleInput_in_output_list; eauto.
      + find_apply_lem_hyp in_output_list_app_or.
        intuition.
        * intermediate_networks.
          find_apply_lem_hyp doLeader_appliedEntries. find_rewrite.
          eapply doGenericServer_output_correct; eauto.
          eapply RIR_handleInput; eauto.
        * exfalso. eapply doLeader_key_in_output_list; eauto.
    - exfalso. eauto using in_output_trace_not_nil.
    - exfalso. eauto using in_output_trace_not_nil.
    - exfalso. eauto using in_output_trace_not_nil.
    - exfalso. eauto using in_output_trace_not_nil.
  Qed.

  Instance TR : TraceRelation step_f :=
    {
      init := step_f_init;
      T := in_output_trace client id out ;
      T_dec := in_output_trace_dec ;
      R := fun s => let (_, net) := s in
                    output_correct client id out (applied_entries (nwState net))
    }.
  Proof.
    - intros. repeat break_let. subst.
      find_eapply_lem_hyp applied_entries_monotonic';
        eauto using step_f_star_raft_intermediate_reachable.
      unfold output_correct in *.
      break_exists.
      repeat find_rewrite.
      match goal with
          | [ |- context [ deduplicate_log (?l ++ ?l') ] ] =>
            pose proof deduplicate_log_app l l'; break_exists; find_rewrite
      end.
      repeat eexists; intuition eauto; repeat find_rewrite; auto.
      rewrite app_ass. simpl. repeat f_equal.
  - unfold in_output_trace in *. intuition.
    break_exists; intuition.
  - intros.
    break_let. subst.
    find_apply_lem_hyp in_output_changed; auto.
    destruct s.
    eauto using in_output_trace_step_output_correct, step_f_star_raft_intermediate_reachable.
  Defined.

  Theorem output_correct :
    forall  failed net tr,
      step_f_star step_f_init (failed, net) tr ->
      in_output_trace client id out tr ->
      output_correct client id out (applied_entries (nwState net)).
  Proof.
    intros. pose proof (trace_relations_work (failed, net) tr).
    repeat concludes.
    auto.
  Qed.
  End inner.

  Instance oci : output_correct_interface.
  Proof.
    split.
    exact output_correct.
  Qed.
End OutputCorrect.
