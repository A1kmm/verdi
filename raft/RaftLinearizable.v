Require Import List.
Import ListNotations.
Require Import Arith.
Require Import Nat.
Require Import Omega.

Require Import Net.
Require Import Util.
Require Import VerdiTactics.

Require Import Raft.
Require Import CommonTheorems.
Require Import Linearizability.
Require Import OutputImpliesApplied.

Section RaftLinearizable.
  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Definition key : Type := nat * nat.

  Definition key_eq_dec : forall x y : key, {x = y} + {x <> y}.
  Proof.
    decide equality; auto using eq_nat_dec.
  Qed.

  Fixpoint import (tr : list (name * (raft_input + list raft_output)))
  : list (op key) :=
    match tr with
      | [] => []
      | (_, (inl (ClientRequest c id cmd))) :: xs =>
        I (c, id) :: import xs
      | (_, (inr l)) :: xs =>
        filterMap (fun x =>
                     match x with
                       | ClientResponse c id cmd => Some (O (c, id))
                       | _ => None
                     end) l ++ import xs
      | _ :: xs => import xs
    end.

  Inductive exported (env_i : key -> option input) (env_o : key -> option output) :
    list (IR key) -> list (input * output) -> Prop :=
  | exported_nil : exported env_i env_o nil nil
  | exported_IO : forall k i o l tr,
                    env_i k = Some i ->
                    env_o k = Some o ->
                    exported env_i env_o l tr ->
                    exported env_i env_o (IRI k :: IRO k :: l) ((i, o) :: tr)
  | exported_IU : forall k i o l tr,
                    env_i k = Some i ->
                    exported env_i env_o l tr ->
                    exported env_i env_o (IRI k :: IRU k :: l) ((i, o) :: tr).

  Require Import Sumbool.
  Require Import Arith.
  
  Fixpoint get_input (tr : list (name * (raft_input + list raft_output))) (k : key)
    : option input :=
    match tr with
      | [] => None
      | (_, (inl (ClientRequest c id cmd))) :: xs =>
        if (sumbool_and _ _ _ _
                        (eq_nat_dec c (fst k))
                        (eq_nat_dec id (snd k))) then
          Some cmd
        else
          get_input xs k
      | _ :: xs => get_input xs k
    end.

  Fixpoint get_output' (os : list raft_output) (k : key) : option output :=
    match os with
      | [] => None
      | ClientResponse c id o :: xs => 
        if (sumbool_and _ _ _ _
                        (eq_nat_dec c (fst k))
                        (eq_nat_dec id (snd k))) then
          Some o
        else
          get_output' xs k
      | _ :: xs => get_output' xs k
    end.

  Fixpoint get_output (tr : list (name * (raft_input + list raft_output))) (k : key)
    : option output :=
    match tr with
      | [] => None
      | (_, (inr os)) :: xs => (match get_output' os k with
                                 | Some o => Some o
                                 | None => get_output xs k
                               end)
      | _ :: xs => get_output xs k
    end.

  Fixpoint log_to_IR (env_o : key -> option output) (log : list entry) : list (IR key) :=
    match log with
      | [] => []
      | mkEntry h client id index term input :: log' =>
        (match env_o (client, id) with
           | None => [IRI (client, id); IRU (client, id)]
           | Some _ => [IRI (client, id); IRO (client, id)]
         end) ++ log_to_IR env_o log'
    end.

  Lemma log_to_IR_good_trace :
    forall env_o log,
      good_trace _ (log_to_IR env_o log).
  Proof.
    intros.
    induction log; simpl in *; auto.
    - repeat break_match; simpl in *; constructor; auto.
  Qed.

  Fixpoint execute_log' (log : list entry) (st : data) (l : list (input * output))
  : (list (input * output) * data) :=
    match log with
      | [] => (l, st)
      | e :: log' => let '(o, st') := handler (eInput e) st in
                    execute_log' log' st' (l ++ [(eInput e, o)])
    end.

  Definition execute_log (log : list entry) : (list (input * output) * data) :=
    execute_log' log init [].

  Definition input_correct (tr : list (name * (raft_input + list raft_output))) :=
    NoDup (filterMap (fun x => match x with
                                | (_, inl (ClientRequest client id _)) => Some (client, id)
                                | _ => None
                              end) tr).

  Lemma fst_execute_log' :
    forall log st tr,
      fst (execute_log' log st tr) = tr ++ fst (execute_log' log st []).
  Proof.
    induction log; intros.
    - simpl. rewrite app_nil_r. auto.
    - simpl. break_let. rewrite IHlog. rewrite app_ass. simpl.
      rewrite IHlog with (tr := [(eInput a, o)]).
      auto.
  Qed.

  Lemma snd_execute_log' :
    forall log st tr,
      snd (execute_log' log st tr) = snd (execute_log' log st []).
  Proof.
    induction log; intros.
    - auto.
    - simpl. break_let. rewrite IHlog.
      rewrite IHlog with (tr := [(eInput a, o)]).
      auto.
  Qed.

  Lemma execute_log_correct' :
    forall log st,
      step_1_star st (snd (execute_log' log st []))
                  (fst (execute_log' log st [])).
  Proof.
    induction log; intros.
    - simpl. constructor.
    - simpl. break_let.
      rewrite fst_execute_log'.
      rewrite snd_execute_log'.
      unfold step_1_star in *.
      econstructor.
      + constructor. eauto.
      + auto.
  Qed.

  Lemma execute_log_correct :
    forall log,
      step_1_star init (snd (execute_log log))
                  (fst (execute_log log)).
  Proof.
    intros. apply execute_log_correct'.
  Qed.

  Lemma in_import_in_trace :
    forall tr k,
      In (O k) (import tr) ->
      exists os h,
        In (h, inr os) tr /\
        exists o, In (ClientResponse (fst k) (snd k) o) os.
  Proof.
    induction tr; intros; simpl in *; intuition.
    repeat break_match; subst; intuition.
    - find_apply_hyp_hyp. break_exists_exists.
      intuition. 
    - simpl in *. intuition; try congruence.
      find_apply_hyp_hyp. break_exists_exists.
      intuition.
    - do_in_app. intuition.
      + find_apply_lem_hyp In_filterMap.
        break_exists. intuition.
        break_match; try congruence.
        find_inversion.
        repeat eexists; intuition eauto.
      + find_apply_hyp_hyp. break_exists_exists.
        intuition.
  Qed.

  Lemma in_applied_entries_in_IR :
    forall log e client id env,
      eClient e = client ->
      eId e = id ->
      In e log ->
      (exists o, env (client, id) = Some o) ->
      In (IRO (client, id)) (log_to_IR env log).
  Proof.
    intros.
    induction log; simpl in *; intuition.
    - subst. break_exists.
      repeat break_match; intuition.
      simpl in *.
      subst. congruence.
    - repeat break_match; in_crush.
  Qed.

  Theorem get_output'_In :
    forall l client id o,
      In (ClientResponse client id o) l ->
      exists o', get_output' l (client, id) = Some o'.
  Proof.
    intros. induction l; simpl in *; intuition.
    - subst. break_if; simpl in *; intuition eauto.
    - break_match; simpl in *; intuition eauto.
      break_if; simpl in *; intuition eauto.
  Qed.
  
  Theorem import_get_output :
    forall tr k,
      In (O k) (import tr) ->
      exists o,
        get_output tr k = Some o.
  Proof.
    intros.
    induction tr; simpl in *; intuition.
    repeat break_match; intuition; subst; simpl in *; intuition; try congruence;
    do_in_app; intuition eauto.
    find_apply_lem_hyp In_filterMap.
    break_exists; break_match; intuition; try congruence.
    subst. find_inversion.
    find_apply_lem_hyp get_output'_In. break_exists; congruence.
  Qed.

  Theorem raft_linearizable :
    forall failed net tr,
      input_correct tr ->
      step_f_star step_f_init (failed, net) tr ->
      exists l tr1 st,
        equivalent _ (import tr) l /\
        exported (get_input tr) (get_output tr) l tr1 /\
        step_1_star init st tr1.
  Proof.
    intros.
    exists (log_to_IR (get_output tr) (applied_entries (nwState net))).
    exists (fst (execute_log (applied_entries (nwState net)))).
    exists (snd (execute_log (applied_entries (nwState net)))).
    intuition eauto using execute_log_correct.
    - eapply equivalent_intro; eauto using log_to_IR_good_trace, key_eq_dec.
      + (* In O -> In IRO *)
        intros.
        find_copy_apply_lem_hyp in_import_in_trace.
        find_eapply_lem_hyp output_implies_applied; eauto.
        unfold in_applied_entries in *.
        break_exists. intuition.
        destruct k; simpl in *.
        eapply in_applied_entries_in_IR; eauto.
        apply import_get_output. auto.
      + (* In IRO -> In O *)
        admit.
      + (* In IRU -> In O *)
        admit.
      + (* before preserved *)
        admit.
      + (* I before O *)
        admit.
      + (* In IRU -> not In O *)
        admit.
      + (* NoDup op input *)
        admit.
      + (* NoDup IR input *)
        admit.
      + (* NoDup op output *)
        admit.
      + (* NoDup IR output *)
        admit.
    - admit.
  Qed.
End RaftLinearizable.
