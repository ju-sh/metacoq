(* Distributed under the terms of the MIT license. *)
From Coq Require Import Morphisms.
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICCases PCUICInduction
     PCUICLiftSubst PCUICSigmaCalculus PCUICTyping PCUICWeakeningEnv PCUICWeakening
     PCUICSubstitution PCUICReduction PCUICCumulativity PCUICGeneration
     PCUICUnivSubst PCUICWeakeningEnv PCUICUnivSubstitution.

From Equations Require Import Equations.
Require Import Equations.Prop.DepElim.
Require Import ssreflect ssrbool.

From MetaCoq.PCUIC Require Import PCUICInduction.

Section CheckerFlags.
  Context {cf:checker_flags}.

  Lemma wf_universe_type1 Σ : wf_universe Σ Universe.type1.
  Proof.
    simpl.
    intros l hin%UnivExprSet.singleton_spec.
    subst l. simpl.
    apply LS.union_spec. right; apply global_levels_Set.
  Qed.

  Lemma wf_universe_super {Σ u} : wf_universe Σ u -> wf_universe Σ (Universe.super u).
  Proof.
    destruct u; cbn.
    1-2:intros _ l hin%UnivExprSet.singleton_spec; subst l; apply wf_universe_type1;
     now apply UnivExprSet.singleton_spec.
    intros Hl.
    intros l hin. 
    eapply Universes.spec_map_succ in hin as [x' [int ->]].
    simpl. now specialize (Hl _ int).
  Qed.

  Lemma wf_universe_sup {Σ u u'} : wf_universe Σ u -> wf_universe Σ u' ->
    wf_universe Σ (Universe.sup u u').
  Proof.
    destruct u, u'; cbn; auto.
    intros Hu Hu' l [Hl|Hl]%UnivExprSet.union_spec.
    now apply (Hu _ Hl).
    now apply (Hu' _ Hl).
  Qed.
  
  Lemma wf_universe_product {Σ u u'} : wf_universe Σ u -> wf_universe Σ u' ->
    wf_universe Σ (Universe.sort_of_product u u').
  Proof.
    intros Hu Hu'. unfold Universe.sort_of_product.
    destruct (Universe.is_prop u' || Universe.is_sprop u'); auto.
    now apply wf_universe_sup.
  Qed.

  Hint Resolve wf_universe_type1 wf_universe_super wf_universe_sup wf_universe_product : pcuic.


  Definition wf_universeb_level Σ l := 
    LevelSet.mem l (global_ext_levels Σ).

  Definition wf_universe_level Σ l := 
    LevelSet.In l (global_ext_levels Σ).
    
  Definition wf_universe_instance Σ u :=
    Forall (wf_universe_level Σ) u.

  Definition wf_universeb_instance Σ u :=
    forallb (wf_universeb_level Σ) u.

  Lemma wf_universe_levelP {Σ l} : reflect (wf_universe_level Σ l) (wf_universeb_level Σ l).
  Proof.
    unfold wf_universe_level, wf_universeb_level.
    destruct LevelSet.mem eqn:ls; constructor.
    now apply LevelSet.mem_spec in ls.
    intros hin.
    now apply LevelSet.mem_spec in hin.
  Qed.

  Lemma wf_universe_instanceP {Σ u} : reflect (wf_universe_instance Σ u) (wf_universeb_instance Σ u).
  Proof.
    unfold wf_universe_instance, wf_universeb_instance.
    apply forallbP. intros x; apply wf_universe_levelP.
  Qed.
  
  Lemma wf_universe_subst_instance_univ (Σ : global_env_ext) univs u l :
    wf Σ ->
    wf_universe Σ l ->
    wf_universe_instance (Σ.1, univs) u ->
    sub_context_set (monomorphic_udecl Σ.2) (global_ext_context_set (Σ.1, univs)) ->
    wf_universe (Σ.1, univs) (subst_instance u l). 
  Proof.
    destruct l; simpl; auto.
    intros wfΣ Hl Hu sub e [[l n] [inl ->]]%In_subst_instance.
    destruct l; simpl; auto.
    - unfold global_ext_levels.
      apply LS.union_spec. right.
      apply global_levels_Set.
    - specialize (Hl (Level.Level s, n) inl).
      simpl in Hl.
      destruct sub. unfold levels_of_udecl in H.
      unfold global_ext_levels in Hl.
      destruct Σ.2.
      * eapply LS.union_spec in Hl.
        destruct Hl as [Hl|Hl].
        + now specialize (H _ Hl).
        + eapply LS.union_spec. now right.
      * eapply LS.union_spec in Hl as [Hl|Hl].
        + simpl in Hl.
          now apply monomorphic_level_notin_AUContext in Hl.
        + apply LS.union_spec; now right.
    - specialize (Hl (Level.Var n0, n) inl).
      eapply LS.union_spec in Hl as [Hl|Hl].
      + red in Hu.
        unfold levels_of_udecl in Hl.
        destruct Σ.2.
        * simpl in Hu. simpl in *.
          unfold subst_instance; simpl.
          destruct nth_error eqn:hnth; simpl.
          eapply nth_error_forall in Hu; eauto.
          eapply LS.union_spec; right. eapply global_levels_Set.
        * simpl in sub.
          unfold subst_instance. simpl.
          destruct (nth_error u n0) eqn:hnth.
          2:{ simpl. rewrite hnth. eapply LS.union_spec; right; apply global_levels_Set. }
          eapply nth_error_forall in Hu. 2:eauto. change (nth_error u n0) with (nth_error u n0) in *.
          rewrite -> hnth. simpl. apply Hu.
      + now apply not_var_global_levels in Hl.
  Qed.

  Lemma wf_universe_instantiate Σ univs s u φ :
    wf Σ ->
    wf_universe (Σ, univs) s ->
    wf_universe_instance (Σ, φ) u ->
    sub_context_set (monomorphic_udecl univs) (global_ext_context_set (Σ, φ)) ->
    wf_universe (Σ, φ) (subst_instance_univ u s).
  Proof.
    intros wfΣ Hs cu.
    apply (wf_universe_subst_instance_univ (Σ, univs) φ); auto.
  Qed.

  Lemma subst_instance_empty u : 
    forallb (fun x => ~~ Level.is_var x) u ->
    subst_instance [] u = u.
  Proof.
    induction u; simpl; intros Hu; auto.
    rewrite subst_instance_cons.
    move/andP: Hu => [] isv Hf.
    rewrite IHu //.
    now destruct a => /= //; auto.
  Qed.

  Lemma wf_universe_level_mono Σ ctx u : 
    wf Σ ->
    on_udecl_prop Σ (Monomorphic_ctx ctx) ->
    Forall (wf_universe_level (Σ, Monomorphic_ctx ctx)) u ->
    forallb (fun x => ~~ Level.is_var x) u.
  Proof.
    intros wf uprop.
    induction 1 => /= //.
    destruct x eqn:isv => /= //.
    apply LS.union_spec in H as [H|H]; simpl in H.
    epose proof (@udecl_prop_in_var_poly _ (Σ, _) _ uprop H) as [ctx' eq].
    discriminate.
    now pose proof (not_var_global_levels _ wf _ H).
  Qed.

  Lemma wf_universe_level_sub Σ ctx univs u :
    wf_universe_level (Σ, Monomorphic_ctx ctx) u ->
    sub_context_set ctx (global_ext_context_set (Σ, univs)) ->
    wf_universe_level (Σ, univs) u.
  Proof.
    intros wfx [sub _].
    red in wfx |- *.
    eapply LevelSet.union_spec in wfx; simpl in *.
    destruct wfx as [wfx|wfx].
    now specialize (sub _ wfx).
    eapply LevelSet.union_spec. now right.
  Qed.

  Lemma wf_universe_instance_sub Σ ctx univs u :
    wf_universe_instance (Σ, Monomorphic_ctx ctx) u ->
    sub_context_set ctx (global_ext_context_set (Σ, univs)) ->
    wf_universe_instance (Σ, univs) u.
  Proof.
    intros wfu [sub ?].
    red in wfu |- *.
    eapply Forall_impl; eauto.
    intros; eapply wf_universe_level_sub; eauto.
    red. split; auto.
  Qed.

  Lemma In_Level_global_ext_poly s Σ cst : 
    LS.In (Level.Level s) (global_ext_levels (Σ, Polymorphic_ctx cst)) ->
    LS.In (Level.Level s) (global_levels Σ).
  Proof.
    intros [hin|hin]%LS.union_spec.
    simpl in hin.
    now apply monomorphic_level_notin_AUContext in hin.
    apply hin.
  Qed.

  Lemma Forall_In (A : Type) (P : A -> Prop) (l : list A) :
    Forall P l -> (forall x : A, In x l -> P x).
  Proof.
    induction 1; simpl; auto.
    intros x' [->|inx]; auto.
  Qed.

  Lemma wf_universe_instance_In {Σ u} : wf_universe_instance Σ u <-> 
    (forall l, In l u -> LS.In l (global_ext_levels Σ)).
  Proof.
    unfold wf_universe_instance.
    split; intros. eapply Forall_In in H; eauto.
    apply In_Forall. auto.
  Qed.

  Lemma in_subst_instance l u u' : 
    In l (subst_instance u u') ->
    In l u \/ In l u' \/ l = Level.lSet.
  Proof.
    induction u'; simpl; auto.
    intros [].
    destruct a; simpl in *; subst; auto.
    destruct (nth_in_or_default n u Level.lSet); auto.
    specialize (IHu' H). intuition auto.
  Qed.

  Lemma wf_universe_subst_instance Σ univs u u' φ : 
    wf Σ ->
    on_udecl_prop Σ univs ->
    wf_universe_instance (Σ, univs) u' ->
    wf_universe_instance (Σ, φ) u ->
    sub_context_set (monomorphic_udecl univs) (global_ext_context_set (Σ, φ)) ->
    wf_universe_instance (Σ, φ) (subst_instance u u').
  Proof.
    intros wfΣ onup Hs cu subc.
    destruct univs.
    - red in Hs |- *.
      unshelve epose proof (wf_universe_level_mono _ _ _ _ _ Hs); eauto.
      eapply forallb_Forall in H. apply Forall_map.
      solve_all. destruct x; simpl => //.
      eapply LS.union_spec. right. eapply global_levels_Set.
      eapply wf_universe_level_sub; eauto.
    - simpl in subc.
      clear subc onup.
      red in Hs |- *.
      eapply Forall_map, Forall_impl; eauto.
      intros x wfx.
      red in wfx. destruct x => /= //.
      red.
      eapply LS.union_spec; right.
      eapply global_levels_Set.
      eapply In_Level_global_ext_poly in wfx.
      apply LS.union_spec; now right.
      eapply in_var_global_ext in wfx; simpl in wfx; auto.
      unfold AUContext.levels, AUContext.repr in wfx.
      destruct cst as [? cst].
      rewrite mapi_unfold in wfx.
      eapply (proj1 (LevelSetProp.of_list_1 _ _)) in wfx.
      apply SetoidList.InA_alt in wfx as [? [<- wfx]]. simpl in wfx.
      eapply In_unfold_inj in wfx; [|congruence].
      destruct (nth_in_or_default n u (Level.lSet)).
      red in cu. eapply Forall_In in cu; eauto. rewrite e.
      red. eapply LS.union_spec. right. eapply global_levels_Set.
  Qed.

  Section WfUniverses.
    Context (Σ : global_env_ext).

    Definition wf_universeb (s : Universe.t) : bool :=
      match s with
      | Universe.lType l => UnivExprSet.for_all (fun l => LevelSet.mem (UnivExpr.get_level l) (global_ext_levels Σ)) l
      | _ => true
      end.

    Lemma wf_universe_reflect {u : Universe.t} : 
      reflect (wf_universe Σ u) (wf_universeb u).
    Proof.
      destruct u; simpl; try now constructor.
      eapply iff_reflect.
      rewrite UnivExprSet.for_all_spec.
      split; intros.
      - intros l Hl; specialize (H l Hl).
        now eapply LS.mem_spec.
      - specialize (H l H0). simpl in H.
        now eapply LS.mem_spec in H.
    Qed.

    Fixpoint wf_universes t := 
      match t with
      | tSort s => wf_universeb s
      | tApp t u
      | tProd _ t u
      | tLambda _ t u => wf_universes t && wf_universes u
      | tCase _ p c brs => 
        wf_universeb_instance Σ p.(puinst) &&
        forallb wf_universes p.(pparams) &&
        test_context (closedu #|p.(puinst)|) p.(pcontext) &&
        wf_universes p.(preturn) && wf_universes c && 
        forallb (test_branch (closedu #|p.(puinst)|) wf_universes) brs
      | tLetIn _ t t' u =>
        wf_universes t && wf_universes t' && wf_universes u
      | tProj _ t => wf_universes t
      | tFix mfix _ | tCoFix mfix _ =>
        forallb (fun d => wf_universes d.(dtype) && wf_universes d.(dbody)) mfix
      | tConst _ u | tInd _ u | tConstruct _ _ u => wf_universeb_instance Σ u
      | tEvar _ args => forallb wf_universes args
      | _ => true
      end.

    Lemma All_forallb {A} (P : A -> Type) l (H : All P l) p p' : (forall x, P x -> p x = p' x) -> forallb p l = forallb p' l.
    Proof.
      intros; induction H; simpl; auto.
      now rewrite IHAll H0.
    Qed.

    Lemma test_context_mapi (p : term -> bool) f (ctx : context) k :
  test_context p (mapi_context (shiftf f k) ctx) = test_context_k (fun k => p ∘ f k) k ctx.
Proof.
  induction ctx; simpl; auto.
  rewrite IHctx. f_equal.
  now rewrite test_decl_map_decl.
Qed.
Hint Rewrite test_context_mapi : map.

Lemma test_context_k_ctx (p : term -> bool) (ctx : context) k :
  test_context p ctx = test_context_k (fun k => p) k ctx.
Proof.
  induction ctx; simpl; auto.
Qed.

    Lemma wf_universes_lift n k t : wf_universes (lift n k t) = wf_universes t.
    Proof.
      induction t in n, k |- * using term_forall_list_ind; simpl; auto; try
        rewrite ?IHt1 ?IHt2 ?IHt3; auto.
      - solve_all.
      - destruct X as [? [? ?]]. solve_all.
        rewrite IHt.
        f_equal. f_equal.
        * unfold test_predicate => /=.
          rewrite /id e. f_equal.
          f_equal. f_equal. solve_all.
        * solve_all.
          rewrite /test_branch. rewrite b. f_equal.
      - rewrite forallb_map.
        eapply All_forallb; eauto. simpl; intros [].
        simpl. intros. cbn. now rewrite H.
      - rewrite forallb_map.
        eapply All_forallb; eauto. simpl; intros [].
        simpl. intros. cbn. now rewrite H.
    Qed.

    Lemma wf_universes_subst s k t :
      All wf_universes s ->
      wf_universes (subst s k t) = wf_universes t.
    Proof.
      intros Hs.
      induction t in k |- * using term_forall_list_ind; simpl; auto; try
        rewrite ?IHt1 ?IHt2 ?IHt3; auto.
      - destruct (Nat.leb_spec k n); auto.
        destruct nth_error eqn:nth; simpl; auto.
        eapply nth_error_all in nth; eauto.
        simpl in nth. intros. now rewrite wf_universes_lift.
      - solve_all.
      - destruct X as [? [? ?]]. solve_all.
        rewrite IHt. f_equal. f_equal.
        unfold test_predicate => /=.
        rewrite /id e. f_equal.
        f_equal. f_equal. solve_all.
        rewrite /shiftf.
        solve_all.
        rewrite /test_branch. rewrite b. f_equal.
      - rewrite forallb_map.
        eapply All_forallb; eauto. simpl; intros [].
        simpl. intros. cbn. now rewrite H.
      - rewrite forallb_map.
        eapply All_forallb; eauto. simpl; intros [].
        simpl. intros. cbn. now rewrite H.
    Qed.

  End WfUniverses.
  Arguments wf_universe_reflect {Σ u}.

  Ltac to_prop := 
    repeat match goal with 
    | [ H: is_true (?x && ?y) |- _ ] =>
     let x := fresh in let y := fresh in move/andP: H; move=> [x y]; rewrite ?x ?y; simpl
    end. 

  Ltac to_wfu := 
    repeat match goal with 
    | [ H: is_true (wf_universeb _ ?x) |- _ ] => apply (elimT (@wf_universe_reflect _ x)) in H
    | [ |- is_true (wf_universeb _ ?x) ] => apply (introT (@wf_universe_reflect _ x))
    end. 
 
  Lemma wf_universes_inst {Σ : global_env_ext} univs t u : 
    wf Σ ->
    on_udecl_prop Σ.1 univs ->
    sub_context_set (monomorphic_udecl univs) (global_ext_context_set Σ) ->
    wf_universe_instance Σ u  ->
    wf_universes (Σ.1, univs) t ->
    wf_universes Σ (subst_instance u t).
  Proof.
    intros wfΣ onudecl sub cu wft.
    induction t using term_forall_list_ind; simpl in *; auto; try to_prop; 
      try apply /andP; to_wfu; intuition eauto 4.
    all:autorewrite with map; repeat (f_equal; solve_all).

    - to_wfu. destruct Σ as [Σ univs']. simpl in *.
      eapply (wf_universe_subst_instance_univ (Σ, univs)); auto.

    - apply/wf_universe_instanceP.
      eapply wf_universe_subst_instance; eauto.
      destruct Σ; simpl in *.
      now move/wf_universe_instanceP: wft.
    - apply/wf_universe_instanceP.
      eapply wf_universe_subst_instance; eauto.
      destruct Σ; simpl in *.
      now move/wf_universe_instanceP: wft.
    - apply/wf_universe_instanceP.
      eapply wf_universe_subst_instance; eauto.
      destruct Σ; simpl in *.
      now move/wf_universe_instanceP: wft.
    
    - cbn. apply/wf_universe_instanceP; auto.
      eapply wf_universe_subst_instance; eauto.
      destruct Σ; simpl in *; auto.
      now move/wf_universe_instanceP: H.
    - now len.
    - rewrite /test_branch. rtoProp.
      move/andP: b => [] tctx wfu.
      split; auto. simpl.
      solve_all. now len.
  Qed.
  
  Lemma weaken_wf_universe Σ Σ' t : wf Σ' -> extends Σ.1 Σ' ->
    wf_universe Σ t ->
    wf_universe (Σ', Σ.2) t.
  Proof.
    intros wfΣ ext.
    destruct t; simpl; auto.
    intros Hl l inl; specialize (Hl l inl).
    apply LS.union_spec. apply LS.union_spec in Hl as [Hl|Hl]; simpl.
    left; auto.
    right. destruct ext as [? ->]. simpl.
    rewrite global_levels_ext.
    eapply LS.union_spec. right; auto.
  Qed.

  Lemma weaken_wf_universe_level Σ Σ' t : wf Σ' -> extends Σ.1 Σ' ->
    wf_universe_level Σ t ->
    wf_universe_level (Σ', Σ.2) t.
  Proof.
    intros wfΣ ext.
    unfold wf_universe_level.
    destruct t; simpl; auto;
    intros; apply LS.union_spec.
    - right. eapply global_levels_Set.
    - eapply LS.union_spec in H as [H|H].
      left; auto.
      right; auto. simpl.
      destruct ext. subst Σ'.
      rewrite global_levels_ext.
      eapply LS.union_spec. right; auto.
    - eapply in_var_global_ext in H; eauto.
      now eapply wf_extends.
  Qed.

  Lemma weaken_wf_universe_instance Σ Σ' t : wf Σ' -> extends Σ.1 Σ' ->
    wf_universe_instance Σ t ->
    wf_universe_instance (Σ', Σ.2) t.
  Proof.
    intros wfΣ ext.
    unfold wf_universe_instance.
    intros H; eapply Forall_impl; eauto.
    intros. now eapply weaken_wf_universe_level.
  Qed.

  Lemma weaken_wf_universes Σ Σ' t : wf Σ' -> extends Σ.1 Σ' ->
    wf_universes Σ t ->
    wf_universes (Σ', Σ.2) t.
  Proof.
    intros wfΣ ext.
    induction t using term_forall_list_ind; simpl in *; auto; intros; to_prop;
    try apply /andP; to_wfu; intuition eauto 4.

  - solve_all.
  - now eapply weaken_wf_universe.
  - apply /andP; to_wfu; intuition eauto 4.
  - apply /wf_universe_instanceP; apply weaken_wf_universe_instance; eauto.
    now apply /wf_universe_instanceP.
  - apply /wf_universe_instanceP; apply weaken_wf_universe_instance; eauto.
    now apply /wf_universe_instanceP.
  - apply /wf_universe_instanceP; apply weaken_wf_universe_instance; eauto.
    now apply /wf_universe_instanceP.
  - apply /andP; to_wfu; intuition eauto 4.
    rewrite /test_predicate. intros; rtoProp.
    destruct X as [? [? ?]].
    intuition auto; solve_all.
    apply /wf_universe_instanceP; apply weaken_wf_universe_instance; eauto.
    now apply /wf_universe_instanceP.
  - red in X; solve_all.
    move/andP: b. rewrite /test_branch. rtoProp.
    solve_all.
  - red in X. solve_all. 
  - red in X. solve_all.
  Qed.

  Lemma wf_universes_weaken_full : weaken_env_prop_full (fun Σ Γ t T => 
      wf_universes Σ t && wf_universes Σ T).
  Proof.
    red. intros.     
    to_prop; apply /andP; split; now apply weaken_wf_universes.
  Qed.

  Lemma wf_universes_weaken :
    weaken_env_prop
      (lift_typing (fun Σ Γ (t T : term) =>
        wf_universes Σ t && wf_universes Σ T)).
  Proof.
    red. intros.
    unfold lift_typing in *. destruct T. now eapply (wf_universes_weaken_full (_, _)).
    destruct X1 as [s Hs]; exists s. now eapply (wf_universes_weaken_full (_, _)).
  Qed.

  Lemma wf_universes_inds Σ mind u bodies : 
    wf_universe_instance Σ u ->
    All (fun t : term => wf_universes Σ t) (inds mind u bodies).
  Proof.
    intros wfu.
    unfold inds.
    generalize #|bodies|.
    induction n; simpl; auto.
    constructor; auto.
    simpl. now apply /wf_universe_instanceP.
  Qed.

  Lemma wf_universes_mkApps Σ f args : 
    wf_universes Σ (mkApps f args) = wf_universes Σ f && forallb (wf_universes Σ) args.
  Proof.
    induction args using rev_ind; simpl; auto. now rewrite andb_true_r.
    rewrite mkApps_app /= IHargs forallb_app /=.
    now rewrite andb_true_r andb_assoc.
  Qed.
    
  Lemma type_local_ctx_wf Σ Γ Δ s : type_local_ctx
    (lift_typing
     (fun (Σ : PCUICEnvironment.global_env_ext)
        (_ : PCUICEnvironment.context) (t T : term) =>
      wf_universes Σ t && wf_universes Σ T)) Σ Γ Δ s ->
      All (fun d => option_default (wf_universes Σ) (decl_body d) true && wf_universes Σ (decl_type d)) Δ.
  Proof.
    induction Δ as [|[na [b|] ty] ?]; simpl; constructor; auto.
    simpl.
    destruct X as [? [? ?]]. now to_prop.
    apply IHΔ. apply X.
    simpl.
    destruct X as [? ?]. now to_prop.
    apply IHΔ. apply X.
  Qed.

  Lemma consistent_instance_ext_wf Σ univs u : consistent_instance_ext Σ univs u ->
    wf_universe_instance Σ u.
  Proof.
    destruct univs; simpl.
    - destruct u => // /=.
      intros _. constructor.
    - intros [H%forallb_Forall [H' H'']].
      eapply Forall_impl; eauto.
      simpl; intros. now eapply LS.mem_spec in H0.
  Qed.

  Ltac specIH :=
    repeat match goal with
    | [ H : on_udecl _ _, H' : on_udecl _ _ -> _ |- _ ] => specialize (H' H)
    end.

  Local Lemma wf_sorts_local_ctx_smash (Σ : global_env_ext) mdecl args sorts :
    sorts_local_ctx
    (lift_typing
       (fun (Σ : PCUICEnvironment.global_env_ext)
          (_ : PCUICEnvironment.context) (t T : term) =>
        wf_universes Σ t && wf_universes Σ T)) (Σ.1, ind_universes mdecl)
    (arities_context (ind_bodies mdecl),,, ind_params mdecl)
    args sorts ->
    sorts_local_ctx
    (lift_typing
       (fun (Σ : PCUICEnvironment.global_env_ext)
          (_ : PCUICEnvironment.context) (t T : term) =>
        wf_universes Σ t && wf_universes Σ T)) (Σ.1, ind_universes mdecl)
    (arities_context (ind_bodies mdecl),,, ind_params mdecl)
    (smash_context [] args) sorts.
  Proof.
    induction args as [|[na [b|] ty] args] in sorts |- *; simpl; auto.
    intros [].
    rewrite subst_context_nil. auto.
    destruct sorts; auto.
    intros [].
    rewrite smash_context_acc /=. split. eauto.
    rewrite wf_universes_subst.
    clear -s. generalize 0.
    induction args as [|[na [b|] ty] args] in sorts, s |- *; simpl in *; auto.
    - destruct s as [? [[s' wf] [? ?]%andb_and]].
      constructor; eauto.
      rewrite wf_universes_subst. eapply IHargs; eauto.
      now rewrite wf_universes_lift.
    - destruct sorts => //. destruct s.
      constructor => //. eapply IHargs; eauto.
    - now rewrite wf_universes_lift.
  Qed.

  Lemma wf_sorts_local_ctx_nth_error Σ P Γ Δ s n d : 
    sorts_local_ctx P Σ Γ Δ s -> 
    nth_error Δ n = Some d ->
    ∑ Γ' t, P Σ Γ' (decl_type d) t.
  Proof.
    induction Δ as [|[na [b|] ty] Δ] in n, s |- *; simpl; auto.
    - now rewrite nth_error_nil.
    - intros [h [h' h'']].
      destruct n. simpl. move=> [= <-] /=. do 2 eexists; eauto.
      now simpl; eapply IHΔ.
    - destruct s => //. intros [h h'].
      destruct n. simpl. move=> [= <-] /=. eexists; eauto.
      now simpl; eapply IHΔ.
  Qed.

  Lemma In_unfold_var x n : In x (unfold n Level.Var) <-> exists k, k < n /\ (x = Level.Var k).
  Proof.
    split.
    - induction n => /= //.
      intros [hin|hin]%in_app_or.
      destruct (IHn hin) as [k [lt eq]].
      exists k; auto.
      destruct hin => //. subst x.
      eexists; eauto.
    - intros [k [lt ->]].
      induction n in k, lt |- *. lia.
      simpl. apply in_or_app.
      destruct (lt_dec k n). left; auto.
      right. left. f_equal. lia.      
  Qed.

  Lemma wf_abstract_instance Σ decl :
    wf_universe_instance (Σ, decl) (abstract_instance decl).
  Proof.
    destruct decl as [|[u cst]]=> /= //.
    red. constructor.
    rewrite /UContext.instance /AUContext.repr /=.
    rewrite mapi_unfold.
    red. eapply In_Forall.
    intros x hin. eapply In_unfold_var in hin as [k [lt eq]].
    subst x. red.
    eapply LS.union_spec; left. simpl.
    rewrite /AUContext.levels /= mapi_unfold.
    eapply (proj2 (LevelSetProp.of_list_1 _ _)).
    apply SetoidList.InA_alt. eexists; split; eauto.
    eapply In_unfold_var. exists k; split; eauto.
  Qed.

  Definition wf_decl_universes Σ d :=
    option_default (wf_universes Σ) d.(decl_body) true &&
    wf_universes Σ d.(decl_type).
  
  Definition wf_ctx_universes Σ Γ :=
    forallb (wf_decl_universes Σ) Γ.
  
  Lemma wf_universes_it_mkProd_or_LetIn {Σ Γ T} : 
    wf_universes Σ (it_mkProd_or_LetIn Γ T) = wf_ctx_universes Σ Γ && wf_universes Σ T.
  Proof.
    induction Γ as [ |[na [b|] ty] Γ] using rev_ind; simpl; auto;
      now rewrite it_mkProd_or_LetIn_app /= IHΓ /wf_ctx_universes forallb_app /=
      {3}/wf_decl_universes; cbn; bool_congr.
  Qed.

  Lemma test_context_app p Γ Δ : 
    test_context p (Γ ,,, Δ) = test_context p Γ && test_context p Δ.
  Proof.
    induction Δ; simpl; auto.
    - now rewrite andb_true_r.
    - now rewrite IHΔ andb_assoc.
  Qed.

  
  Lemma wf_universes_it_mkLambda_or_LetIn {Σ Γ T} : 
    wf_universes Σ (it_mkLambda_or_LetIn Γ T) = test_context (wf_universes Σ) Γ && wf_universes Σ T.
  Proof.
    induction Γ as [ |[na [b|] ty] Γ] using rev_ind; simpl; auto;
      now rewrite it_mkLambda_or_LetIn_app /= IHΓ test_context_app /= /test_decl /= andb_assoc.
  Qed.
  
  Lemma wf_projs Σ ind npars p :
    All (fun t : term => wf_universes Σ t) (projs ind npars p).
  Proof.
    induction p; simpl; auto.
  Qed.

  Lemma wf_extended_subst Σ Γ n :
    wf_ctx_universes Σ Γ ->
    All (fun t : term => wf_universes Σ t) (extended_subst Γ n).
  Proof.
    induction Γ as [|[na [b|] ty] Γ] in n |- *; simpl; auto.
    move=> /andP []; rewrite /wf_decl_universes /= => /andP [] wfb wfty wfΓ.
    constructor; eauto. rewrite wf_universes_subst //. now apply IHΓ.
    now rewrite wf_universes_lift. eauto.
    move=> /andP []; rewrite /wf_decl_universes /= => wfty wfΓ.
    constructor; eauto.
  Qed.

  Lemma closedu_compare_decls k Γ Δ :
    All2 (PCUICEquality.compare_decls eq eq) Γ Δ ->
    test_context (closedu k) Γ = test_context (closedu k) Δ.
  Proof.
    induction 1; cbn; auto.
    f_equal; auto. destruct r; subst; auto.
  Qed.

  Lemma closedu_mkApps k f args : closedu k (mkApps f args) = closedu k f && forallb (closedu k) args.
  Proof.
    induction args in f |- *; cbn; auto. ring.
    rewrite IHargs /=. ring.
  Qed.

  Lemma closedu_abstract_instance univs : closedu_instance #|abstract_instance univs| (abstract_instance univs).
  Proof. 
    destruct univs as [|[l csts]] => // /=.
    rewrite /UContext.instance /AUContext.repr.
    rewrite /closedu_instance forallb_mapi //.
    intros i hi. cbn; len. now eapply Nat.ltb_lt.
  Qed.

  Notation closedu_ctx k := (test_context (closedu k)).

  Lemma closedu_lift k n k' t :
    closedu k (lift n k' t) = closedu k t.
  Proof.
    induction t in k' |- * using term_forall_list_ind; cbn; auto; intros; solve_all.
    - rewrite IHt.
      rewrite /map_predicate_k /= /test_predicate /test_predicate_ku /= /id.
      f_equal. f_equal. rewrite e. f_equal. f_equal. f_equal.
      solve_all.
      solve_all.
      rewrite /map_branch_k /test_branch /=. f_equal.
      now rewrite b.
    - rewrite /test_def /map_def /=. now rewrite a b.
    - rewrite /test_def /map_def /=. now rewrite a b.
  Qed.

  Ltac try_hyp := 
    multimatch goal with H : _ |- _ => eapply H end.
      
  Ltac crush := repeat (solve_all; try try_hyp; cbn).


  Lemma closedu_subst k s k' t :
    forallb (closedu k) s && closedu k t ->
    closedu k (subst s k' t).
  Proof.
    Ltac t := repeat (solve_all; try try_hyp).
    induction t in k' |- * using term_forall_list_ind; cbn; auto; intros;
      try solve [t].
    - destruct Nat.leb => //.
      destruct nth_error eqn:eq => //.
      rewrite closedu_lift.
      eapply nth_error_forallb in eq; tea. solve_all.
    - unfold test_predicate_ku in *. unfold test_branch in *. crush.
    - unfold test_def in *; crush.
    - unfold test_def in *; crush.
  Qed.

  Lemma closedu_subst_context k s k' Γ :
    forallb (closedu k) s && closedu_ctx k Γ ->
    closedu_ctx k (subst_context s k' Γ).
  Proof.
    rewrite /subst_context.
    induction Γ.
    * cbn; auto.
    * rtoProp. intros []. cbn in H0. rtoProp.
      rewrite fold_context_k_snoc0 /= IHΓ //. crush.
      unfold test_decl in *. crush.
      destruct decl_body eqn:heq => /= //.
      rewrite closedu_subst //. crush. 
      rewrite closedu_subst //. crush.
  Qed.

  Lemma closedu_lift_context k n k' Γ :
    closedu_ctx k (lift_context n k' Γ) = closedu_ctx k Γ.
  Proof.
    rewrite /lift_context.
    induction Γ.
    * cbn; auto.
    * rtoProp.
      rewrite fold_context_k_snoc0 /= IHΓ //. 
      unfold test_decl in *. 
      cbn.
      rewrite closedu_lift. 
      destruct (decl_body a) => /= //.
      rewrite closedu_lift //.
  Qed.

  Lemma closedu_extended_subst k Γ k' : 
    closedu_ctx k Γ ->
    forallb (closedu k) (extended_subst Γ k').
  Proof.
    induction Γ in k' |- *; cbn; auto. destruct a as [na [b|] ty] => /= //.
    unfold test_decl; move/andP=> [] clΓ /= cld. apply/andP. split. 
    eapply closedu_subst. rewrite IHΓ // /= closedu_lift. crush.
    now rewrite IHΓ.
    unfold test_decl; move/andP=> [] clΓ /= cld. now apply IHΓ.
  Qed.

  Lemma closedu_expand_lets_ctx k Γ Δ :
    closedu_ctx k Γ && closedu_ctx k Δ ->
    closedu_ctx k (expand_lets_ctx Γ Δ). 
  Proof.
    rewrite /expand_lets_ctx /expand_lets_k_ctx.
    move/andP => [] clΓ clΔ.
    apply closedu_subst_context.
    rewrite closedu_extended_subst // /= closedu_lift_context //.
  Qed.

  Lemma closedu_smash_context_gen k Γ Δ :
    closedu_ctx k Γ -> closedu_ctx k Δ ->
    closedu_ctx k (smash_context Γ Δ). 
  Proof.
    induction Δ in Γ |- *; cbn; auto.
    move=> clΓ /andP[] clΔ cla.
    destruct a as [na [b|] ty] => //.
    - apply IHΔ => //. apply closedu_subst_context => /= //.
      now move/andP: cla => [] /= -> clty.
    - apply IHΔ => //.
      now rewrite test_context_app clΓ /= andb_true_r.
  Qed.
  
  Lemma closedu_smash_context k Δ :
    closedu_ctx k Δ ->
    closedu_ctx k (smash_context [] Δ). 
  Proof.
    apply closedu_smash_context_gen => //.
  Qed.
  
  Lemma wf_universe_level_closed {Σ : global_env} {wfΣ : wf Σ} univs u :
    on_udecl_prop Σ univs ->
    wf_universe_level (Σ, univs) u -> closedu_level #|polymorphic_instance univs| u.
  Proof.
    intros ond Ht; destruct u => //. 
    cbn in Ht. unfold closedu_universe, closedu_universe_levels.
    cbn. red in Ht.
    eapply in_var_global_ext in Ht => //.
    cbn in Ht.
    destruct (udecl_prop_in_var_poly (Σ := (Σ, univs)) ond Ht) as [ctx eq].
    cbn in eq. subst univs.
    cbn in Ht. cbn. unfold AUContext.levels in Ht.
    eapply (proj1 (LevelSetProp.of_list_1 _ _)) in Ht.
    eapply InA_In_eq in Ht.
    destruct ctx as [names cstrs].
    unfold AUContext.repr in Ht |- *. cbn in *. len.
    rewrite mapi_unfold in Ht. eapply In_unfold_var in Ht as [k []].
    eapply Nat.leb_le. noconf H0. lia.
  Qed.

  Lemma wf_universe_closed {Σ : global_env} {wfΣ : wf Σ} univs u :
    on_udecl_prop Σ univs ->
    wf_universe (Σ, univs) u -> closedu #|polymorphic_instance univs| (tSort u).
  Proof.
    intros ond Ht; destruct u => //. 
    cbn in Ht. unfold closedu_universe, closedu_universe_levels.
    eapply UnivExprSet.for_all_spec.
    intros x y ?; subst; auto.
    intros i hi. specialize (Ht i hi).
    unfold closedu_level_expr.
    apply wf_universe_level_closed => //.
  Qed.

  Lemma wf_universe_instance_closed {Σ : global_env} {wfΣ : wf Σ} {univs u} :
    on_udecl_prop Σ univs ->
    wf_universe_instance (Σ, univs) u -> 
    closedu_instance #|polymorphic_instance univs| u.
  Proof.
    intros ond Ht.
    red in Ht. unfold closedu_instance. solve_all.
    now eapply wf_universe_level_closed.
  Qed.

  Lemma wf_universes_closedu {Σ : global_env} {wfΣ : wf Σ} {univs t} :
    on_udecl_prop Σ univs ->
    wf_universes (Σ, univs) t -> closedu #|polymorphic_instance univs| t.
  Proof.
    intros ond. induction t using term_forall_list_ind; cbn => //; solve_all.
    - apply wf_universe_closed => //.
      now move/wf_universe_reflect: H.
    - eapply wf_universe_instance_closed => //.
      now move/wf_universe_instanceP: H.
    - eapply wf_universe_instance_closed => //.
      now move/wf_universe_instanceP: H.
    - eapply wf_universe_instance_closed => //.
      now move/wf_universe_instanceP: H.
    - unfold test_predicate_ku in *; solve_all.
      eapply wf_universe_instance_closed => //.
      now move/wf_universe_instanceP: H0.
    - unfold test_branch in *; solve_all.
    - unfold test_def in *; solve_all.
    - unfold test_def in *; solve_all.
  Qed.

  Lemma wf_ctx_universes_closed {Σ} {wfΣ : wf Σ} {univs ctx} :
    on_udecl_prop Σ univs ->
    wf_ctx_universes (Σ, univs) ctx ->
    closedu_ctx #|polymorphic_instance univs| ctx.
  Proof.
    intros ond. induction ctx => //.
    rewrite /wf_ctx_universes /= => /andP[] wfa wfctx.
    rewrite IHctx // /=.
    unfold wf_decl_universes, test_decl in *.
    destruct a as [na [b|] ty]; cbn in *.
    move/andP: wfa => []. 
    now do 2 move/(wf_universes_closedu ond) => ->.
    now move/(wf_universes_closedu ond): wfa => ->.
  Qed.


  Lemma closedu_reln k Γ k' acc : 
    closedu_ctx k Γ ->
    forallb (closedu k) acc ->
    forallb (closedu k) (reln acc k' Γ).
  Proof.
    induction Γ in acc, k' |- *; cbn; auto.
    destruct a as [na [b|] ty] => /= //.
    - unfold test_decl; move/andP=> [] clΓ /= cld. now eapply IHΓ.
    - unfold test_decl; move/andP=> [] clΓ /= cld clacc; now apply IHΓ => //.
  Qed.

  Lemma closedu_to_extended_list_k k Γ k' : 
    closedu_ctx k Γ ->
    forallb (closedu k) (to_extended_list_k Γ k').
  Proof.
    intros clΓ. apply closedu_reln => //.
  Qed.

  Lemma closed_ind_predicate_context {Σ ind mdecl idecl} {wfΣ : wf Σ} :
    declared_inductive Σ ind mdecl idecl ->
    closedu_ctx #|polymorphic_instance (ind_universes mdecl)|
        (ind_params mdecl) ->
    closedu_ctx #|polymorphic_instance (ind_universes mdecl)|
            (ind_indices idecl) ->
    test_context (closedu #|abstract_instance (ind_universes mdecl)|) (ind_predicate_context ind mdecl idecl).
  Proof.
    intros decli.
    rewrite /ind_predicate_context; cbn.
    rewrite closedu_mkApps /=.
    rewrite closedu_abstract_instance /= => clpars clinds.
    apply/andP; split.
    * apply closedu_expand_lets_ctx. now rewrite clpars clinds.
    * apply closedu_to_extended_list_k.
      rewrite test_context_app.
      rewrite (closedu_smash_context _ _ clpars).
      apply closedu_expand_lets_ctx => //.
      now rewrite clpars.
  Qed.

  Lemma closedu_inds {Σ ind mdecl} {wfΣ : wf Σ} :
    forallb (closedu #|abstract_instance (ind_universes mdecl)|)
      (inds ind (abstract_instance (ind_universes mdecl)) (ind_bodies mdecl)).
  Proof.
    rewrite /inds.
    induction #|ind_bodies mdecl|; cbn; auto.
    rewrite IHn andb_true_r.
    eapply closedu_abstract_instance.
  Qed.

  Theorem wf_types :
    env_prop (fun Σ Γ t T => 
      wf_universes Σ t && wf_universes Σ T)
      (fun Σ Γ =>
      All_local_env
      (lift_typing (fun (Σ : global_env_ext) (Γ : context) (t T : term) =>
         wf_universes Σ t && wf_universes Σ T) Σ) Γ ×
         test_context (wf_universes Σ) Γ).
  Proof.
    apply typing_ind_env; intros; rename_all_hyps; simpl; specIH; to_prop; simpl; auto.

    - split.
      * induction X; constructor; auto.
        destruct tu as [s tu]; exists s; simpl.
        now simpl in p.
        destruct tu as [s tu]; exists s; simpl.
        now simpl in p.
      * induction X; simpl; auto.
        rewrite IHX /= /test_decl /=. now move/andP: p.
        rewrite IHX /= /test_decl /=. now move/andP: p => [] -> ->.

    - rewrite wf_universes_lift.
      destruct X as [X _].
      pose proof (nth_error_Some_length heq_nth_error).
      eapply nth_error_All_local_env in X; tea.
      rewrite heq_nth_error /= in X. red in X.
      destruct decl as [na [b|] ty]; cbn -[skipn] in *.
      + now to_prop.
      + destruct X as [s Hs]. now to_prop.

    - apply/andP; split; to_wfu; eauto with pcuic.
       
    - simpl in *; to_wfu; eauto with pcuic.
    - rewrite wf_universes_subst. constructor. to_wfu; auto. constructor.
      now move/andP: H4 => [].

    - apply/andP; split.
      { apply/wf_universe_instanceP.
        eapply consistent_instance_ext_wf; eauto. }
      pose proof (declared_constant_inv _ _ _ _ wf_universes_weaken wf X H).
      red in X1; cbn in X1.
      destruct (cst_body decl).
      * to_prop.
        epose proof (weaken_lookup_on_global_env'' Σ.1 _ _ wf H).
        epose proof (weaken_lookup_on_global_env' Σ.1 _ _ wf H).
        eapply wf_universes_inst. 2:eauto. all:eauto.
        simpl in H3.
        eapply sub_context_set_trans; eauto.
        eapply global_context_set_sub_ext.
        now eapply consistent_instance_ext_wf.
      * move: X1 => [s /andP[Hc _]].
        to_prop.
        eapply wf_universes_inst; eauto.
        exact (weaken_lookup_on_global_env' Σ.1 _ _ wf H).
        epose proof (weaken_lookup_on_global_env'' Σ.1 _ _ wf H).
        eapply sub_context_set_trans; eauto.
        eapply global_context_set_sub_ext.
        now eapply consistent_instance_ext_wf.

    - apply/andP; split.
      { apply/wf_universe_instanceP.
        eapply consistent_instance_ext_wf; eauto. }
      pose proof (declared_inductive_inv wf_universes_weaken wf X isdecl).
      cbn in X1. eapply onArity in X1. cbn in X1.
      move: X1 => [s /andP[Hind ?]].
      eapply wf_universes_inst; eauto.
      exact (weaken_lookup_on_global_env' Σ.1 _ _ wf (proj1 isdecl)).
      generalize (weaken_lookup_on_global_env'' Σ.1 _ _ wf (proj1 isdecl)).
      simpl. intros H'.
      eapply sub_context_set_trans; eauto.
      eapply global_context_set_sub_ext.
      now eapply consistent_instance_ext_wf.

    - apply/andP; split.
      { apply/wf_universe_instanceP.
        eapply consistent_instance_ext_wf; eauto. }
      pose proof (declared_constructor_inv wf_universes_weaken wf X isdecl) as [sc [nthe onc]].
      unfold type_of_constructor.
      rewrite wf_universes_subst.
      { apply wf_universes_inds.
        now eapply consistent_instance_ext_wf. }
      eapply on_ctype in onc. cbn in onc.
      move: onc=> [_ /andP[onc _]].
      eapply wf_universes_inst; eauto.
      exact (weaken_lookup_on_global_env' Σ.1 _ _ wf (proj1 (proj1 isdecl))).
      generalize (weaken_lookup_on_global_env'' Σ.1 _ _ wf (proj1 (proj1 isdecl))).
      simpl. intros H'.
      eapply sub_context_set_trans; eauto.
      eapply global_context_set_sub_ext.
      now eapply consistent_instance_ext_wf.
    
    - rewrite wf_universes_mkApps in H5.
      move/andP: H5 => /= [] wfu; rewrite forallb_app.
      move/andP=> [] wfpars wfinds. rewrite wfu /= wfpars wf_universes_mkApps /= 
        forallb_app wfinds /= H /= !andb_true_r.
      pose proof (declared_inductive_inv wf_universes_weaken wf X isdecl).
      destruct X2. destruct onArity as [s Hs].
      move/andP: Hs => [] /= hty hs.
      rewrite ind_arity_eq in hty.
      rewrite !wf_universes_it_mkProd_or_LetIn in hty.
      move/and3P: hty => [] wfp wfindis wfisort.
      have ond : on_udecl_prop Σ (ind_universes mdecl).
      { eapply (weaken_lookup_on_global_env' _ _ (InductiveDecl mdecl)); auto.
        eapply isdecl. }
      eapply wf_ctx_universes_closed in wfp => //.
      eapply wf_ctx_universes_closed in wfindis => //.
      rewrite (consistent_instance_length H1).
      erewrite closedu_compare_decls; tea.
      rewrite closed_ind_predicate_context // /=.
      unfold test_branch.
      apply/andP; split.
      * have wfbrctx : All (fun cdecl =>
          closedu_ctx #|polymorphic_instance (ind_universes mdecl)| (cstr_args cdecl))
          (ind_ctors idecl).
        { clear -wf ond onConstructors.
          red in onConstructors. solve_all. destruct X.
          do 2 red in on_ctype. destruct on_ctype as [s Hs].
          move/andP: Hs => [] wfty _.
          rewrite cstr_eq in wfty.
          rewrite !wf_universes_it_mkProd_or_LetIn in wfty.
          move/and3P: wfty => [] _ clargs _.
          apply wf_ctx_universes_closed in clargs => //. }
        solve_all.
        erewrite closedu_compare_decls; [|tea].
        rewrite /cstr_branch_context.
        eapply closedu_expand_lets_ctx.
        rewrite wfp. eapply closedu_subst_context.
        rewrite a1.
        now rewrite closedu_inds.
      * rewrite /ptm.
        rewrite wf_universes_it_mkLambda_or_LetIn H4 andb_true_r.
        rewrite /predctx.
        destruct X3 as [_ hctx]. move: hctx.
        now rewrite test_context_app => /andP[].

    - rewrite /subst1. rewrite wf_universes_subst.
      constructor => //. eapply All_rev.
      rewrite wf_universes_mkApps in H1.
      move/andP: H1 => [].
      now intros _ hargs%forallb_All.
      pose proof (declared_projection_inv wf_universes_weaken wf X isdecl).
      destruct (declared_inductive_inv); simpl in *.
      destruct ind_ctors as [|cs []] => //.
      destruct ind_cunivs as [|cunivs []] => //;
      destruct X1 as [[[? ?] ?] ?] => //.
      red in o0.
      destruct nth_error eqn:heq => //. 
      subst ty. destruct o0  as [_ ->].
      rewrite wf_universes_mkApps in H1.
      move/andP: H1 => [/wf_universe_instanceP wfu wfargs].

      eapply (wf_universes_inst (ind_universes mdecl)); eauto.
      exact (weaken_lookup_on_global_env' Σ.1 _ _ wf (proj1 (proj1 (proj1 isdecl)))).
      generalize (weaken_lookup_on_global_env'' Σ.1 _ _ wf (proj1 (proj1 (proj1 isdecl)))).
      simpl. intros H'.
      eapply sub_context_set_trans; eauto.
      eapply global_context_set_sub_ext.
      rewrite wf_universes_subst.
      eapply wf_universes_inds; eauto.
      eapply wf_abstract_instance.
      rewrite wf_universes_subst. apply wf_projs.
      rewrite wf_universes_lift.
      rewrite smash_context_app smash_context_acc in heq.
      autorewrite with len in heq. rewrite nth_error_app_lt in heq.
      autorewrite with len. lia.
      rewrite nth_error_subst_context in heq.
      autorewrite with len in heq. simpl in heq.
      epose proof (nth_error_lift_context_eq _ (smash_context [] (ind_params mdecl)) _ _).
      autorewrite with len in H. simpl in H. rewrite -> H in heq. clear H.
      autorewrite with len in heq.
      simpl in heq.
      destruct nth_error eqn:hnth; simpl in * => //.
      noconf heq. simpl.
      rewrite wf_universes_subst.
      apply wf_extended_subst.
      rewrite ind_arity_eq in onArity. destruct onArity as [s' Hs].
      rewrite wf_universes_it_mkProd_or_LetIn in Hs.
      now move/andP: Hs => /andP /andP [] /andP [].
      rewrite wf_universes_lift.
      eapply wf_sorts_local_ctx_smash in s.
      eapply wf_sorts_local_ctx_nth_error in s as [? [? H]]; eauto.
      red in H. destruct x0. now move/andP: H => [].
      now destruct H as [s [Hs _]%andb_and]. 
    
    - apply/andP; split; auto.
      solve_all. now rewrite wf_universes_lift in H2.
      eapply nth_error_all in X0; eauto.
      simpl in X0. now move: X0 => [s [Hty /andP[wfty _]]].

    - apply/andP; split; auto.
      solve_all. now rewrite wf_universes_lift in H2.
      eapply nth_error_all in X0; eauto.
      simpl in X0. now move: X0 => [s [Hty /andP[wfty _]]].
  Qed.

  Lemma typing_wf_universes {Σ : global_env_ext} {Γ t T} : 
    wf Σ ->
    Σ ;;; Γ |- t : T -> wf_universes Σ t && wf_universes Σ T.
  Proof.
    intros wfΣ Hty.
    exact (env_prop_typing wf_types _ wfΣ _ _ _ Hty).
  Qed.

  Lemma typing_wf_universe {Σ : global_env_ext} {Γ t s} : 
    wf Σ ->
    Σ ;;; Γ |- t : tSort s -> wf_universe Σ s.
  Proof.
    intros wfΣ Hty.
    apply typing_wf_universes in Hty as [_ wfs]%andb_and; auto.
    simpl in wfs. now to_wfu.
  Qed.

  Lemma isType_wf_universes {Σ Γ T} : wf Σ.1 -> isType Σ Γ T -> wf_universes Σ T.
  Proof.
    intros wfΣ [s Hs]. now eapply typing_wf_universes in Hs as [HT _]%andb_and.
  Qed.
  
End CheckerFlags.

Arguments wf_universe_reflect {Σ u}.
#[global] Hint Resolve wf_universe_type1 wf_universe_super wf_universe_sup wf_universe_product : pcuic.

#[global]
Hint Extern 4 (wf_universe _ ?u) => 
  match goal with
  [ H : typing _ _ _ (tSort u) |- _ ] => apply (typing_wf_universe _ H)
  end : pcuic.
