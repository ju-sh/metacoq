(* Distributed under the terms of the MIT license. *)
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils
     PCUICLiftSubst PCUICTyping PCUICWeakening PCUICCases
     PCUICCumulativity PCUICReduction
     PCUICParallelReduction PCUICEquality PCUICUnivSubstitution
     PCUICParallelReductionConfluence PCUICConfluence
     PCUICContextReduction PCUICOnFreeVars PCUICWellScopedCumulativity.

From MetaCoq.PCUIC Require Export PCUICContextRelation.

From Coq Require Import CRelationClasses ssreflect ssrbool.
From Equations Require Import Equations.

Arguments red_ctx : clear implicits.

Ltac my_rename_hyp h th :=
  match th with
    | (typing _ _ ?t _) => fresh "type" t
    | (All_local_env (@typing _) _ ?G) => fresh "wf" G
    | (All_local_env (@typing _) _ _) => fresh "wf"
    | (All_local_env _ _ ?G) => fresh "H" G
    | context [typing _ _ (_ ?t) _] => fresh "IH" t
  end.

Ltac rename_hyp h ht ::= my_rename_hyp h ht.

Implicit Types (cf : checker_flags) (Σ : global_env_ext).

#[global]
Hint Resolve conv_refl' : pcuic.
Arguments skipn : simpl never.

Definition closed_red_ctx Σ Γ Γ' :=
  All2_fold (fun Γ _ => All_decls (closed_red Σ Γ)) Γ Γ'.

Notation "Σ ⊢ Γ ⇝ Δ" := (closed_red_ctx Σ Γ Δ) (at level 50, Γ, Δ at next level,
  format "Σ  ⊢  Γ  ⇝  Δ") : pcuic.

Notation "Σ ⊢ Γ ≤[ le ] Δ" := (context_equality le Σ Γ Δ) (at level 50, Γ, Δ at next level,
  format "Σ  ⊢  Γ  ≤[ le ]  Δ") : pcuic.

Notation "Σ ⊢ Γ = Δ" := (context_equality false Σ Γ Δ) (at level 50, Γ, Δ at next level,
  format "Σ  ⊢  Γ  =  Δ") : pcuic.

Notation "Σ ⊢ Γ ≤ Δ" := (context_equality true Σ Γ Δ) (at level 50, Γ, Δ at next level,
  format "Σ  ⊢  Γ  ≤  Δ") : pcuic.

Lemma closed_red_ctx_red_ctx {Σ Γ Γ'} : 
  Σ ⊢ Γ ⇝ Γ' -> red_ctx Σ Γ Γ'.
Proof.
  intros a; eapply All2_fold_impl; tea.
  cbn; intros ?????.
  eapply All_decls_impl; tea => t t'.
  now move=> [].
Qed.
Coercion closed_red_ctx_red_ctx : closed_red_ctx >-> red_ctx.

#[global]
Hint Constructors red1 : pcuic.
#[global]
Hint Resolve refl_red : pcuic.

Section ContextReduction.
  Context {cf : checker_flags}.
  Context (Σ : global_env).
  Context (wfΣ : wf Σ).

  Local Definition red1_red_ctxP Γ Γ' :=
    (forall n b b',
        option_map decl_body (nth_error Γ n) = Some (Some b) ->
        option_map decl_body (nth_error Γ' n) = Some (Some b') ->
        @red_ctx Σ (skipn (S n) Γ) (skipn (S n) Γ') ->
        ∑ t, red Σ (skipn (S n) Γ') b t * red Σ (skipn (S n) Γ') b' t).

  Lemma red_ctx_skip i Γ Γ' :
    red1_red_ctxP Γ Γ' ->
    red1_red_ctxP (skipn i Γ) (skipn i Γ').
  Proof.
    rewrite /red1_red_ctxP => H n b b'.
    rewrite !nth_error_skipn => H0 H1.
    specialize (H (i + n)).
    rewrite !skipn_skipn. rewrite - !Nat.add_succ_comm.
    move=> H'.
    eapply H; auto.
  Qed.

  Lemma All2_fold_over_red_refl {Γ Δ} :
    All2_fold (on_decls (fun (Δ _ : context) (t u : term) => red Σ (Γ ,,, Δ) t u)) Δ Δ.
  Proof. induction Δ as [|[na [b|] ty]]; econstructor; try red; auto. 
    constructor; reflexivity. constructor; reflexivity.
  Qed.

  Lemma All2_fold_red_refl {Δ} :
    All2_fold (on_decls (fun (Δ _ : context) (t u : term) => red Σ Δ t u)) Δ Δ.
  Proof. 
    induction Δ as [|[na [b|] ty]]; econstructor; try red; auto;
    constructor; reflexivity.
  Qed.

  Derive Signature for assumption_context.

  Lemma red1_red_ctxP_app {Γ Γ' Δ} : 
    red1_red_ctxP Γ Γ' ->
    red1_red_ctxP (Γ ,,, Δ) (Γ' ,,, Δ).
  Proof.
    induction Δ as [|[na [b|] ty] Δ]; intros; auto.
    - case.
      * move=> bod bod' => /= [=] -> [=] ->. rewrite !skipn_S !skipn_0. exists bod'.
        split; reflexivity.
      * move=> /= n bod b' hn hn' r.
        specialize (IHΔ X n bod b' hn hn' r) as [t [redl redr]].
        exists t. rewrite !skipn_S in r |- *. split; auto.
    - case; move => n b b' //. eapply IHΔ. apply X.
  Qed.

  Ltac t := split; [eapply red1_red; try econstructor; eauto|try constructor]; eauto with pcuic.
  Ltac u := intuition eauto with pcuic.

  Lemma red_ctx_app Γ Γ' Δ : 
    red_ctx Σ Γ Γ' -> red_ctx Σ (Γ ,,, Δ) (Γ' ,,, Δ).
  Proof.
    intros h; eapply All2_fold_app => //.
    eapply All2_fold_refl. intros Δ' ?. reflexivity.
  Qed.
  Hint Resolve red_ctx_app : pcuic.

  Lemma red_ctx_on_free_vars P Γ Γ' :
    red_ctx Σ Γ Γ' ->
    on_free_vars_ctx P Γ ->
    on_free_vars_ctx P Γ'.
  Proof.
    move=> /red_ctx_red_context r onΓ.
    pose proof (All2_fold_length r).
    move: r => /red_context_on_ctx_free_vars.
    move: onΓ. now rewrite - !on_free_vars_ctx_on_ctx_free_vars -H.
  Qed.

  Lemma red1_red_ctx_aux {Γ Γ' T U} :
    red1 Σ Γ T U ->
    on_free_vars xpredT T ->
    on_free_vars_ctx xpredT Γ ->
    @red_ctx Σ Γ Γ' ->
    red1_red_ctxP Γ Γ' ->
    ∑ t, red Σ Γ' T t * red Σ Γ' U t.
  Proof.
    intros r onT onΓ H. revert onT onΓ Γ' H.
    simpl in *. induction r using red1_ind_all; intros; auto with pcuic; 
    repeat inv_on_free_vars_xpredT.
    all:try solve [eexists; t].
    all:try specialize (IHr ltac:(tea) ltac:(eauto with fvs)).
    all:try destruct (IHr _ ltac:(tea) ltac:(tea)) as [? [? ?]]; auto.

    - pose proof H.
      eapply nth_error_pred1_ctx_l in H as [body' [? ?]]; eauto.
      rewrite -(firstn_skipn (S i) Γ').
      assert (i < #|Γ'|). destruct (nth_error Γ' i) eqn:Heq; noconf e. eapply nth_error_Some_length in Heq. lia.
      move: (All2_fold_length H0) => Hlen.
      specialize (X _ _ _ H1 e). forward X. eapply All2_fold_app_inv.
      instantiate (1 := firstn (S i) Γ').
      instantiate (1 := firstn (S i) Γ).
      rewrite !firstn_length. lia.
      now rewrite !(firstn_skipn (S i) _).
      destruct X as [x' [bt b't]]. exists (lift0 (S i) x').
      split; eauto with pcuic.
      * etransitivity. eapply red1_red. constructor.
        rewrite firstn_skipn. eauto. cbn in *.
        eapply red_ctx_on_free_vars in onΓ. 2:tea.
        eapply weakening_red_0; eauto.
        rewrite firstn_length_le //.
        erewrite on_free_vars_ctx_on_ctx_free_vars.
        rewrite -(firstn_skipn (S i) Γ') on_free_vars_ctx_app in onΓ.
        now move/andP: onΓ => [].
        destruct (nth_error Γ' i) eqn:hnth => //.
        epose proof (nth_error_on_free_vars_ctx xpredT 0 Γ' i c).
        forward H2. rewrite addnP0. eauto with fvs.
        forward H2 by auto.
        specialize (H2 hnth). noconf e.
        move/andP: H3 => [] /=. rewrite H /=.
        rewrite PCUICInst.addnP_xpredT shiftnP_xpredT //.
      * epose proof (red_ctx_on_free_vars _ _ _ H0 onΓ).
        eapply weakening_red_0; eauto.
        rewrite firstn_length_le //.
        erewrite on_free_vars_ctx_on_ctx_free_vars.
        rewrite -(firstn_skipn (S i) Γ') on_free_vars_ctx_app in H2.
        now move/andP: H2 => [].
        destruct (nth_error Γ i) eqn:hnth => //.
        epose proof (nth_error_on_free_vars_ctx xpredT 0 Γ i c).
        forward H3. rewrite addnP0. eauto with fvs.
        forward H3 by auto.
        specialize (H3 hnth). noconf H1.
        move/andP: H3 => [] /=. rewrite H /=.
        eauto with fvs.

    - exists (tLambda na x N). split; apply red_abs; auto.

    - destruct (IHr (Γ' ,, vass na N)). constructor; pcuic. constructor; pcuic.
      case => ? ? /= //. apply X.
      exists (tLambda na N x). split; apply red_abs; u.

    - exists (tLetIn na x t b'). split; eapply red_letin; auto.
    - specialize (IHr (Γ' ,, vdef na b t)).
      forward IHr. constructor; eauto. constructor; auto.
      destruct IHr as [? [? ?]].
      case. move=> b0 b1 [] <- [] <- H'. exists b; auto.
      apply X.
      exists (tLetIn na b t x). split; eapply red_letin; auto.
    - solve_all. eapply OnOne2_All_mix_left in X; tea.
      eapply (OnOne2_exist _ (red Σ Γ')) in X as [pars' [ol or]].
      exists (tCase ci (set_pparams p pars') c brs). u.
      apply red_case_pars. eapply OnOne2_All2; tea => /= //.
      change (set_pparams p pars') with (set_pparams (set_pparams p params') pars').
      apply red_case_pars => /=. eapply OnOne2_All2; tea => /= //.
      intros; u.
    - destruct (IHr (Γ' ,,, inst_case_predicate_context p)).
      now eapply red_ctx_app => //.
      now eapply red1_red_ctxP_app.
      destruct p5.
      eexists. split. eapply red_case_p; tea.
      change (set_preturn p x) with (set_preturn (set_preturn p preturn') x).
      eapply red_case_p; tea.
    - exists (tCase ind p x brs). u; now apply red_case_c.
    - solve_all. eapply OnOne2_All_mix_left in X; tea.
      eapply (OnOne2_exist _ 
        (fun br br' => on_Trel_eq (red Σ (Γ' ,,, inst_case_branch_context p br)) bbody bcontext br br')) in X.
        destruct X as [brs'' [? ?]].
        eexists. split; eapply red_case_one_brs; eauto;
        solve_all.
        intros. intuition eauto.
        inv_on_free_vars_xpredT.
        specialize (b1 ltac:(eauto with fvs)).
        forward b1. eapply on_free_vars_ctx_inst_case_context_xpredT; eauto with fvs. solve_all.
        now rewrite test_context_k_closed_on_free_vars_ctx in a0.
        specialize (b1 (Γ' ,,, inst_case_branch_context p y)) as [body' [rl rr]].
        + rewrite /inst_case_branch_context -b0. now eapply red_ctx_app => //.
        + rewrite /inst_case_branch_context -b0. now eapply red1_red_ctxP_app.
        + exists {| bcontext := bcontext x; bbody := body' |}; cbn; split; rewrite -?b;
          intuition eauto.
          rewrite /inst_case_branch_context b0 //.
    - exists (tProj p x). u; now eapply red_proj_c.
    - exists (tApp x M2). u; now eapply red_app.
    - exists (tApp M1 x). u; now eapply red_app.
    - exists (tProd na x M2). u; now eapply red_prod.
    - specialize (IHr (Γ' ,, vass na M1)) as [? [? ?]].
      constructor; pcuic. constructor; auto. case => //.
      exists (tProd na M1 x). u; now eapply red_prod.
    - eapply OnOne2_All_mix_left in X; tea.
      eapply (OnOne2_exist _ (red Σ Γ')) in X.
      destruct X as [rl [l0 l1]].
      eexists; split; eapply red_evar; eauto.
      eapply OnOne2_All2; eauto.
      eapply OnOne2_All2; eauto.
      simpl; intros.
      intuition eauto.
    - eapply OnOne2_All_mix_left in X; tea.
       eapply (OnOne2_exist _ (on_Trel_eq (red Σ Γ') dtype (fun x => (dname x, dbody x, rarg x)))) in X.
      destruct X as [mfix' [l r]].
      exists (tFix mfix' idx); split; eapply red_fix_ty.
      eapply OnOne2_All2; intuition eauto; intuition.
      eapply OnOne2_All2; intuition eauto; intuition.
      intuition auto. inv_on_free_vars_xpredT.
      specialize (b1 a0 onΓ).
      destruct (b1 _ H X0) as [d' [r0 r1]].
      refine (existT _ {| dtype := d' |} _); simpl; eauto.
    - assert (fix_context mfix0 = fix_context mfix1).
      { rewrite /fix_context /mapi. generalize 0 at 2 4.
        induction X. destruct p. simpl. intuition congruence.
        intros. specialize (IHX (S n)). simpl. congruence. }
      eapply OnOne2_All_mix_left in X; tea.
      eapply (OnOne2_exist _ (on_Trel_eq (red Σ (Γ' ,,, fix_context mfix0)) dbody (fun x => (dname x, dtype x, rarg x)))) in X.
      destruct X as [mfix' [l r]].
      exists (tFix mfix' idx); split; eapply red_fix_body.
      eapply OnOne2_All2; intuition eauto; intuition.
      eapply OnOne2_All2; intuition eauto; intuition. congruence.
      intros.
      intuition auto. inv_on_free_vars_xpredT.
      specialize (b1 ltac:(eauto with fvs) ltac:(eauto with fvs) (Γ' ,,, fix_context mfix0)). forward b1.
      eapply All2_fold_app => //. apply All2_fold_over_red_refl.
      forward b1. now eapply red1_red_ctxP_app.
      destruct b1 as [t [? ?]].
      refine (existT _ {| dbody := t |} _); simpl; eauto.
    - eapply OnOne2_All_mix_left in X; tea.
      eapply (OnOne2_exist _ (on_Trel_eq (red Σ Γ') dtype (fun x => (dname x, dbody x, rarg x)))) in X.
      destruct X as [mfix' [l r]].
      exists (tCoFix mfix' idx); split; eapply red_cofix_ty.
      eapply OnOne2_All2; intuition eauto; intuition.
      eapply OnOne2_All2; intuition eauto; intuition.
      intuition auto. inv_on_free_vars_xpredT.
      destruct (b1 byfvs byfvs _ H X0) as [d' [r0 r1]].
      refine (existT _ {| dtype := d' |} _); simpl; eauto.
    - assert (fix_context mfix0 = fix_context mfix1).
      { rewrite /fix_context /mapi. generalize 0 at 2 4.
        induction X. destruct p. simpl. intuition congruence.
        intros. specialize (IHX (S n)). simpl. congruence. }
      eapply OnOne2_All_mix_left in X; tea.
      eapply (OnOne2_exist _ (on_Trel_eq (red Σ (Γ' ,,, fix_context mfix0)) dbody (fun x => (dname x, dtype x, rarg x)))) in X.
      destruct X as [mfix' [l r]].
      exists (tCoFix mfix' idx); split; eapply red_cofix_body.
      eapply OnOne2_All2; intuition eauto; intuition.
      eapply OnOne2_All2; intuition eauto; intuition. congruence.
      intros. intuition auto. inv_on_free_vars_xpredT.
      specialize (b1 byfvs byfvs (Γ' ,,, fix_context mfix0)). forward b1.
      eapply All2_fold_app => //. apply All2_fold_over_red_refl.
      forward b1. eapply red1_red_ctxP_app => //.
      destruct b1 as [t [? ?]].
      refine (existT _ {| dbody := t |} _); simpl; eauto.
  Qed.

  Hint Resolve red_ctx_on_free_vars : fvs.

  Lemma red_red_ctx' {Γ : closed_context} Γ' {T : open_term Γ} {U} :
    red Σ Γ T U ->
    @red_ctx Σ Γ Γ' ->
    red1_red_ctxP Γ Γ' ->
    ∑ t, red Σ Γ' T t * red Σ Γ' U t.
  Proof.
    intros r rc rP. destruct T as [T hT]; cbn in *; induction r.
    - eapply red1_red_ctx_aux; eauto with fvs.
    - exists x; split; auto.
    - destruct IHr1 as [xl [redl redr]]; eauto with fvs.
      destruct IHr2 as [xr [redl' redr']]; eauto with fvs.
      assert (on_free_vars_ctx xpred0 Γ'). eapply red_ctx_on_free_vars; tea. eauto with fvs.
      pose proof (All2_fold_length rc).
      unshelve epose proof (red_confluence (Γ := exist Γ' _) (t := exist y _) redr redl'); cbn; eauto with fvs.
      rewrite -H0; eauto with fvs.
      destruct X as [v' [redxl redxr]].
      exists v'. split; [transitivity xl|transitivity xr]; auto.
  Qed.

  Lemma red_red_ctx_aux' {Γ : closed_context} {Γ'} :
    @red_ctx Σ Γ Γ' -> red1_red_ctxP Γ Γ'.
  Proof.
    destruct Γ as [Γ onΓ].
    intros X. cbn in *.
    induction Γ in Γ', X, onΓ |- *.
    - depelim X.
      intros n t t'. rewrite nth_error_nil //.
    - depelim X.
      move: onΓ; rewrite on_free_vars_ctx_snoc => /andP /= [onΓ ond].
      depelim a0.
      + specialize (IHΓ byfvs _ X).
        case => n b b' /= //.
        simpl. apply IHΓ.
      + specialize (IHΓ byfvs _ X).
        case.
        * move=> b0 b1 [] <- [] <- H.
          rewrite skipn_S /skipn /= in H.
          move/andP: ond => /= [] onb ont.
          eapply (@red_red_ctx' (exist Γ onΓ) _ (exist b onb)) in H; eauto.
        * simpl. eapply IHΓ.
  Qed.

  Lemma red_red_ctx {Γ : closed_context} {Γ'} {T : open_term Γ} {U} :
    red Σ Γ T U ->
    @red_ctx Σ Γ Γ' ->
    ∑ t, red Σ Γ' T t * red Σ Γ' U t.
  Proof.
    intros. eapply red_red_ctx', red_red_ctx_aux'; eauto.
  Qed.
  
End ContextReduction.

Definition inj_closed (Γ : context) (o : on_free_vars_ctx xpred0 Γ) : closed_context :=
  exist Γ o.
Arguments inj_closed Γ & o.

Definition inj_open {Γ : closed_context} (t : term) (o : on_free_vars (shiftnP #|Γ| xpred0) t) : open_term Γ :=
  exist t o.
Arguments inj_open {Γ} & t o.

#[global] Hint Resolve red_ctx_on_free_vars : fvs.

Lemma red_ctx_on_free_vars_term {Σ P Γ Γ' t} :
  red_ctx Σ Γ Γ' -> 
  on_free_vars (shiftnP #|Γ| P) t ->
  on_free_vars (shiftnP #|Γ'| P) t.
Proof.
  intros r. now rewrite (All2_fold_length r).
Qed.
#[global] Hint Resolve red_ctx_on_free_vars_term : fvs.

#[global]
Instance closed_red_trans Σ Γ : Transitive (closed_red Σ Γ).
Proof.
  intros x y z.
  induction 1. destruct 1. split; eauto with fvs.
  now transitivity y.
Qed.

Definition compare_context {cf} le Σ := 
  eq_context_upto Σ (eq_universe Σ) (compare_universe le Σ).

#[global]
Instance compare_universe_refl {cf} le Σ : RelationClasses.Reflexive (compare_universe le Σ).
Proof.
  destruct le; tc.
Qed.

#[global]
Instance compare_universe_trans {cf} le Σ : RelationClasses.Transitive (compare_universe le Σ).
Proof.
  destruct le; tc.
Qed.

#[global]
Instance compare_universe_substu {cf} le Σ : SubstUnivPreserving (compare_universe le Σ).
Proof.
  destruct le; tc.
Qed.

#[global]
Instance compare_universe_subrel {cf} le Σ : RelationClasses.subrelation (eq_universe Σ) (compare_universe le Σ).
Proof.
  destruct le; tc.
Qed.

#[global]
Instance compare_universe_preorder {cf} le Σ : RelationClasses.PreOrder (compare_universe le Σ).
Proof.
  destruct le; tc.
Qed.


Section ContextConversion.
  Context {cf : checker_flags}.
  Context {Σ : global_env_ext}.
  Context {wfΣ : wf Σ}.

  Notation conv_context := (All2_fold (conv_decls Σ)).
  Notation cumul_context := (All2_fold (cumul_decls Σ)).

  Hint Resolve conv_ctx_refl' cumul_ctx_refl' : pcuic.

  Lemma fill_le {Γ : closed_context} {t u : open_term Γ} {t' u'} :
    leq_term Σ.1 Σ t u -> red Σ Γ t t' -> red Σ Γ u u' ->
    ∑ t'' u'', red Σ Γ t' t'' * red Σ Γ u' u'' * leq_term Σ Σ t'' u''.
  Proof.
    intros tu tt' uu'.
    eapply red_eq_term_upto_univ_l in tu; try exact tt'. all:try tc.
    destruct tu as [u'' [uu'' t'u'']].
    destruct (red_confluence uu' uu'') as [unf [ul ur]].
    eapply red_eq_term_upto_univ_r in t'u''; try exact ur; try tc.
    destruct t'u'' as [t'' [t't'' t''unf]].
    exists t'', unf. intuition auto.
  Qed.

  Lemma fill_eq {Γ : closed_context} {t u : open_term Γ} {t' u'} :
    eq_term Σ.1 Σ t u -> red Σ Γ t t' -> red Σ Γ u u' ->
    ∑ t'' u'', red Σ Γ t' t'' * red Σ Γ u' u'' * eq_term Σ.1 Σ t'' u''.
  Proof.
    intros tu tt' uu'.
    pose proof tu as tu2.
    eapply red_eq_term_upto_univ_l in tu; try exact tt'; try tc.
    destruct tu as [u'' [uu'' t'u'']].
    destruct (red_confluence uu' uu'') as [unf [ul ur]].
    eapply red_eq_term_upto_univ_r in t'u''; try exact ur; try tc.
    destruct t'u'' as [t'' [t't'' t''unf]].
    exists t'', unf. intuition auto.
    Qed.

  Lemma red_ctx_context_equality {l Γ Γ'} : Σ ⊢ Γ ⇝ Γ' -> Σ ⊢ Γ ≤[l] Γ'.
  Proof.
    induction 1; constructor; auto.
    depelim p; constructor; eauto with fvs; pcuic.
  Qed.

  Lemma red_ctx_closed_left {Γ Γ'} : Σ ⊢ Γ ⇝ Γ' -> is_closed_context Γ.
  Proof.
    induction 1; simpl; auto.
    rewrite on_free_vars_ctx_snoc IHX /=.
    destruct p; eauto with fvs.
  Qed.

  Lemma red_ctx_closed_right {Γ Γ'} : Σ ⊢ Γ ⇝ Γ' -> is_closed_context Γ'.
  Proof.
    induction 1; simpl; auto.
    rewrite on_free_vars_ctx_snoc IHX /=.
    destruct p; rewrite -(All2_fold_length X); cbn; eauto with fvs.
    eapply closed_red_open_right in c.
    eapply closed_red_open_right in c0.
    eauto with fvs.
  Qed.
  Hint Resolve red_ctx_closed_left red_ctx_closed_right : fvs.

  Lemma red_compare_term_l {le Γ} {u v u' : term} :
    compare_term le Σ Σ u u' ->
    red Σ Γ u v -> 
    ∑ v' : term, red Σ Γ u' v' × compare_term le Σ Σ v v'.
  Proof.
    destruct le; cbn;
    apply red_eq_term_upto_univ_l; tc.
  Qed.

  Lemma red_compare_term_r {le Γ} {u v u' : term} :
    compare_term le Σ Σ u u' ->
    red Σ Γ u' v -> 
    ∑ v' : term, red Σ Γ u v' × compare_term le Σ Σ v' v.
  Proof.
    destruct le; cbn;
    apply red_eq_term_upto_univ_r; tc.
  Qed.

  Lemma closed_red_compare_term_l {le Γ} {u v u' : term} :
    is_open_term Γ u' ->
    compare_term le Σ Σ u u' ->
    Σ ;;; Γ ⊢ u ⇝ v -> 
    ∑ v' : term, Σ ;;; Γ ⊢ u' ⇝ v' × compare_term le Σ Σ v v'.
  Proof.
    intros isop comp [clΓ clu red].
    destruct (red_compare_term_l comp red) as [nf [r eq]].
    exists nf; repeat (split; eauto with fvs). 
  Qed.

  Lemma closed_red_compare_term_r {le Γ} {u v u' : term} :
    is_open_term Γ u ->
    compare_term le Σ Σ u u' ->
    Σ ;;; Γ ⊢ u' ⇝ v -> 
    ∑ v' : term, Σ ;;; Γ ⊢ u ⇝ v' × compare_term le Σ Σ v' v.
  Proof.
    intros isop comp [clΓ clu red].
    destruct (red_compare_term_r comp red) as [nf [r eq]].
    exists nf; repeat (split; eauto with fvs). 
  Qed.

  Lemma closed_red_red_ctx {Γ Γ'} {T U} :
    Σ ⊢ Γ ⇝ Γ' ->
    Σ ;;; Γ ⊢ T ⇝ U ->
    ∑ t, Σ ;;; Γ' ⊢ T ⇝ t × Σ ;;; Γ' ⊢ U ⇝ t.
  Proof.
    intros rctx [clΓ clT r].
    assert (is_open_term Γ U) by eauto with fvs.
    eapply (red_red_ctx Σ wfΣ (Γ := exist Γ clΓ) (T := exist T clT)) in r as [t [r r']].
    2:exact rctx.
    exists t. split. split; auto. eauto with fvs. 
    rewrite -(length_of rctx); eauto with fvs.
    split; eauto with fvs.
    rewrite -(length_of rctx); eauto with fvs.
  Qed.

  Lemma equality_red {le} {Γ t u} :
    Σ ;;; Γ ⊢ t ≤[le] u <~> 
    ∑ v v', [× Σ ;;; Γ ⊢ t ⇝ v, Σ ;;; Γ ⊢ u ⇝ v' &
      compare_term le Σ (global_ext_constraints Σ) v v'].
  Proof.    
    split.
    - move/equality_alt; intros (v & v' & [clΓ clt clu red red' leq]).
      exists v, v'; repeat split; eauto with fvs.
    - intros (v & v' & [red red' leq]).
      apply equality_alt; exists v, v'.
      repeat split; eauto with fvs.
  Qed.

  Lemma closed_red_confluence {Γ} {t u v} :
    Σ ;;; Γ ⊢ t ⇝ u -> Σ ;;; Γ ⊢ t ⇝ v ->
    ∑ v', Σ ;;; Γ ⊢ u ⇝ v' × Σ ;;; Γ ⊢ v ⇝ v'.
  Proof.
    intros [clΓ clT r] [clΓ' clT' r'].
    destruct (red_confluence (Γ := exist Γ clΓ) (t := exist t clT) r r') as [v' [redl redr]].
    cbn in *. exists v'; repeat split; eauto with fvs.
  Qed.
  
  Lemma equality_red_ctx {le} {Γ Γ'} {T U} :
    Σ ⊢ Γ ⇝ Γ' ->
    Σ ;;; Γ ⊢ T ≤[le] U ->
    Σ ;;; Γ' ⊢ T ≤[le] U.
  Proof.
    intros Hctx H.
    apply equality_red in H as (v & v' & [redl redr leq]).
    destruct (closed_red_red_ctx Hctx redl) as [lnf [redl0 redr0]].
    eapply equality_red.
    eapply closed_red_compare_term_l in leq as [? [? ?]]. 3:exact redr0.
    2:{ rewrite -(length_of Hctx). now eapply closed_red_open_right. }
    destruct (closed_red_red_ctx Hctx redr) as [rnf [redl1 redr1]].
    destruct (closed_red_confluence c redr1) as [nf [redl' redr']].
    unshelve epose proof (closed_red_compare_term_r _ c0 redl') as [lnf' [? ?]]. exact byfvs.
    exists lnf', nf. split; eauto with fvs.
    - now transitivity lnf.
    - now transitivity rnf.
  Qed.

  Lemma red_red_ctx_inv {Γ Δ : closed_context} {t : open_term Γ} {u} :
    red Σ Γ t u -> red_ctx Σ Δ Γ -> red Σ Δ t u.
  Proof.
    intros r rc.
    eapply red_ctx_red_context in rc.
    eapply PCUICContextReduction.red_red_ctx; tea; eauto with fvs.
  Qed.

  Lemma red_red_ctx_inv' {Γ Δ : context} {t u} :
    Σ ⊢ Δ ⇝ Γ -> 
    Σ ;;; Γ ⊢ t ⇝ u -> 
    Σ ;;; Δ ⊢ t ⇝ u.
  Proof.
    intros rc [onΓ ont r].
    move: (red_ctx_closed_left rc) => onΔ.
    eapply closed_red_ctx_red_ctx in rc.
    eapply red_ctx_red_context in rc.
    eapply PCUICContextReduction.red_red_ctx in r.
    econstructor; tea. all:eauto with fvs.
    all:try now rewrite (All2_fold_length rc).
    all:eauto with fvs.
    rewrite -(All2_fold_length rc); eauto with fvs.
  Qed.

  Lemma cumul_red_ctx_inv {le} {Γ Γ' : context} {T U : term} :
    Σ ;;; Γ ⊢ T ≤[le] U ->
    Σ ⊢ Γ' ⇝ Γ ->
    Σ ;;; Γ' ⊢ T ≤[le] U.
  Proof.
    intros H Hctx.
    apply equality_red in H as (v & v' & [redl redr leq]).
    epose proof (red_red_ctx_inv' Hctx redl).
    epose proof (red_red_ctx_inv' Hctx redr).
    apply equality_red.
    now exists v, v'.
  Qed.
  
  Lemma red_eq_context_upto_l {R Re} {Γ Δ} {u} {v}
        `{RelationClasses.Reflexive _ R} `{RelationClasses.Transitive _ R} `{SubstUnivPreserving R}
        `{RelationClasses.Reflexive _ Re} `{RelationClasses.Transitive _ Re} `{SubstUnivPreserving Re}
        `{RelationClasses.subrelation _ Re R} :
    red Σ Γ u v ->
    eq_context_upto Σ Re R Γ Δ ->
    ∑ v',
    red Σ Δ u v' *
    eq_term_upto_univ Σ Re Re v v'.
  Proof.
    intros r HΓ.
    induction r.
    - eapply (red1_eq_context_upto_l _ (Rle:=R)) in r; eauto.
      destruct r as [v [? ?]]. exists v. intuition pcuic.
    - exists x. split; auto. reflexivity.
    - destruct IHr1 as [v' [? ?]]; eauto with fvs.
      destruct IHr2 as [v'' [? ?]]; eauto with fvs.
      eapply (red_eq_term_upto_univ_l _ _ (u:=y) (v:=v'') (u':=v')) in e; try tc. all:pcuic.
      destruct e as [? [? ?]].
      exists x0; split; eauto.
      now transitivity v'.
      eapply eq_term_upto_univ_trans with v''; auto.
  Qed.

  Lemma red_eq_context_upto_r {R Re Γ Δ} {u} {v}
        `{RelationClasses.Equivalence _ Re} `{SubstUnivPreserving Re}
        `{RelationClasses.PreOrder _ R} `{SubstUnivPreserving R}
        `{RelationClasses.subrelation _ Re R} :
    red Σ Δ u v ->
    eq_context_upto Σ Re R Γ Δ ->
    ∑ v',
    red Σ Γ u v' *
    eq_term_upto_univ Σ Re Re v v'.
  Proof.
    intros r HΓ.
    induction r.
    - eapply (red1_eq_context_upto_r _ Re R) in r; eauto.
      destruct r as [v [? ?]]. exists v. intuition pcuic.
      now symmetry.
    - exists x. split; auto. reflexivity.
    - destruct IHr1 as [v' [? ?]].
      destruct IHr2 as [v'' [? ?]].
      unshelve eapply (red_eq_term_upto_univ_l Σ _ (Γ := Γ) (u:=y) (v:=v'') (u':=v')) in e. all:pcuic.
      destruct e as [? [? ?]].
      exists x0; split; eauto.
      transitivity v'; auto.
      eapply eq_term_upto_univ_trans with v''; auto; tc.
  Qed.

  Lemma closed_red_eq_context_upto_l {le Γ Δ} {u} {v} :
    is_closed_context Δ ->
    Σ ;;; Γ ⊢ u ⇝ v ->
    compare_context le Σ Γ Δ ->
    ∑ v', Σ ;;; Δ ⊢ u ⇝ v' × eq_term Σ Σ v v'.
  Proof.
    intros clΔ [onΓ onu r] c.
    destruct (red_eq_context_upto_l r c) as [nf [red eq]].
    exists nf. split; auto. split; eauto with fvs.
    now rewrite -(All2_fold_length c).
  Qed.

  Lemma closed_red_eq_context_upto_r {le Γ Δ} {u} {v} :
    is_closed_context Γ ->
    Σ ;;; Δ ⊢ u ⇝ v ->
    compare_context le Σ Γ Δ ->
    ∑ v', Σ ;;; Γ ⊢ u ⇝ v' × eq_term Σ Σ v v'.
  Proof.
    intros clΔ [onΓ onu r] c.
    destruct (red_eq_context_upto_r r c) as [nf [red eq]].
    exists nf. split; auto. split; eauto with fvs.
    now rewrite (All2_fold_length c).
  Qed.

  Lemma cumul_trans_red_leqterm {Γ : closed_context} {t u v : open_term Γ} :
    Σ ;;; Γ |- t <= u -> Σ ;;; Γ |- u <= v ->
    ∑ l o r, red Σ Γ t l *
             red Σ Γ u o *
             red Σ Γ v r *
             leq_term Σ.1 Σ l o * leq_term Σ.1 Σ o r.
  Proof.
    intros X X0.
    intros.
    eapply cumul_alt in X as [t0 [u0 [[redl redr] eq]]].
    eapply cumul_alt in X0 as [u1 [v0 [[redl' redr'] eq']]].
    destruct (red_confluence redr redl') as [unf [nfl nfr]].
    eapply red_eq_term_upto_univ_r in eq; try tc. 2:tea.
    destruct eq as [t1 [red'0 eq2]].
    eapply red_eq_term_upto_univ_l in eq'; try tc; tea.
    destruct eq' as [v1 [red'1 eq1]].
    exists t1, unf, v1.
    repeat split.
    transitivity t0; auto.
    transitivity u0; auto.
    transitivity v0; auto. eapply eq2. eapply eq1.
  Qed.

  Lemma conv_eq_context_upto {Γ} {Δ} {T U} :
    eq_context_upto Σ (eq_universe Σ) (eq_universe Σ) Γ Δ ->
    Σ ;;; Γ |- T = U ->
    Σ ;;; Δ |- T = U.
  Proof.
    intros eqctx cum.
    eapply conv_alt_red in cum as [nf [nf' [[redl redr] ?]]].
    eapply (red_eq_context_upto_l (R:=eq_universe _) (Re:=eq_universe _)) in redl; tea; tc.
    eapply (red_eq_context_upto_l (R:=eq_universe _) (Re:=eq_universe _)) in redr; tea; tc.
    destruct redl as [v' [redv' eqv']].
    destruct redr as [v'' [redv'' eqv'']].
    eapply conv_alt_red. exists v', v''; intuition auto.
    transitivity nf.
    now symmetry. now transitivity nf'.
  Qed.
  
  Lemma conv_leq_context_upto {Γ Δ T U} :
    eq_context_upto Σ (eq_universe Σ) (leq_universe Σ) Γ Δ ->
    Σ ;;; Δ |- T = U ->
    Σ ;;; Γ |- T = U.
  Proof.
    intros eqctx cum.
    eapply conv_alt_red in cum as [nf [nf' [[redl redr] ?]]].
    eapply (red_eq_context_upto_r (Re:=eq_universe _) (R:=leq_universe _)) in redl; tea.
    eapply (red_eq_context_upto_r (Re:=eq_universe _) (R:=leq_universe _)) in redr; tea.
    destruct redl as [v' [redv' eqv']].
    destruct redr as [v'' [redv'' eqv'']].
    eapply conv_alt_red. exists v', v''; intuition auto.
    transitivity nf.
    now symmetry. now transitivity nf'.
  Qed.

  (* Conversion is untyped so this currently holds as context equality 
     just allows cumulativity on types, which do not participate in reduction. 
     However the useful lemma is the one above that shows we can lift a 
     conversion from a large context to a smaller one (contravariance).    
     *)
  Local Remark conv_eq_context_upto_leq_inv {Γ Δ T U} :
    eq_context_upto Σ (eq_universe Σ) (leq_universe Σ) Γ Δ ->
    Σ ;;; Γ |- T = U ->
    Σ ;;; Δ |- T = U.
  Proof.
    intros eqctx cum.
    eapply conv_alt_red in cum as [nf [nf' [[redl redr] ?]]].
    eapply (red_eq_context_upto_l (Re:=eq_universe _) (R:=leq_universe _)) in redl; tea.
    eapply (red_eq_context_upto_l (Re:=eq_universe _) (R:=leq_universe _)) in redr; tea.
    destruct redl as [v' [redv' eqv']].
    destruct redr as [v'' [redv'' eqv'']].
    eapply conv_alt_red. exists v', v''; intuition auto.
    transitivity nf.
    now symmetry. now transitivity nf'.
  Qed.

  Lemma cumul_leq_context_upto {Γ Δ T U} :
    eq_context_upto Σ (eq_universe Σ) (leq_universe Σ) Δ Γ ->
    Σ ;;; Γ |- T <= U ->
    Σ ;;; Δ |- T <= U.
  Proof.
    intros eqctx cum.
    eapply cumul_alt in cum as [nf [nf' [[redl redr] ?]]].
    eapply (red_eq_context_upto_r (Re:=eq_universe Σ) (R:=leq_universe _)) in redl; tea.
    eapply (red_eq_context_upto_r (Re:=eq_universe Σ) (R:=leq_universe _)) in redr; tea.
    destruct redl as [v' [redv' eqv']].
    destruct redr as [v'' [redv'' eqv'']].
    eapply cumul_alt. exists v', v''; intuition auto.
    transitivity nf.
    apply eq_term_leq_term. now symmetry.
    transitivity nf'; auto.
    now apply eq_term_leq_term.
  Qed.

  Lemma equality_compare_context {le le' Γ Δ T U} :
    compare_context le Σ Δ Γ ->
    is_closed_context Δ ->
    Σ ;;; Γ ⊢ T ≤[le'] U ->
    Σ ;;; Δ ⊢ T ≤[le'] U.
  Proof.
    intros eqctx cl cum.
    eapply equality_red in cum as [nf [nf' [redl redr ?]]].
    eapply closed_red_eq_context_upto_r in redl; tea; eauto with fvs.
    eapply closed_red_eq_context_upto_r in redr; tea; eauto with fvs.
    destruct redl as [v' [redv' eqv']].
    destruct redr as [v'' [redv'' eqv'']].
    eapply equality_red. exists v', v''; split; auto.
    destruct le'; cbn in *; transitivity nf.
    apply eq_term_leq_term. now symmetry.
    transitivity nf' => //.
    now apply eq_term_leq_term. now symmetry.
    transitivity nf'; auto.
  Qed.
  
  Local Remark equality_compare_context_inv {le le' Γ Δ T U} :
    compare_context le Σ Γ Δ ->
    is_closed_context Δ ->
    Σ ;;; Γ ⊢ T ≤[le'] U ->
    Σ ;;; Δ ⊢ T ≤[le'] U.
  Proof.
    intros eqctx cl cum.
    eapply equality_red in cum as [nf [nf' [redl redr ?]]].
    eapply closed_red_eq_context_upto_l in redl; tea; eauto with fvs.
    eapply closed_red_eq_context_upto_l in redr; tea; eauto with fvs.
    destruct redl as [v' [redv' eqv']].
    destruct redr as [v'' [redv'' eqv'']].
    eapply equality_red. exists v', v''; split; auto.
    destruct le'; cbn in *; transitivity nf.
    apply eq_term_leq_term. now symmetry.
    transitivity nf' => //.
    now apply eq_term_leq_term. now symmetry.
    transitivity nf'; auto.
  Qed.

  (* Local Remark cumul_leq_context_upto_inv {Γ Δ T U} :
    eq_context_upto Σ (eq_universe Σ) (leq_universe Σ) Γ Δ ->
    Σ ;;; Γ |- T <= U ->
    Σ ;;; Δ |- T <= U.
  Proof.
    intros eqctx cum.
    eapply cumul_alt in cum as [nf [nf' [[redl redr] ?]]].
    eapply (red_eq_context_upto_l (Re:=eq_universe Σ) (R:=leq_universe Σ) (Δ:=Δ)) in redl; tas.
    eapply (red_eq_context_upto_l (Re:=eq_universe Σ) (R:=leq_universe Σ) (Δ:=Δ)) in redr; tas.
    destruct redl as [v' [redv' eqv']].
    destruct redr as [v'' [redv'' eqv'']].
    eapply cumul_alt. exists v', v''; intuition auto.
    eapply leq_term_trans with nf.
    apply eq_term_leq_term. now apply eq_term_sym.
    eapply leq_term_trans with nf'; auto.
    now apply eq_term_leq_term.
  Qed. *)

  Lemma eq_context_upto_impl {Re Rle} {Re' Rle'} {Γ Δ}
    `{RelationClasses.subrelation _ Re Re'}
    `{RelationClasses.subrelation _ Rle Rle'}
    `{RelationClasses.subrelation _ Re' Rle'} :
    eq_context_upto Σ Re Rle Γ Δ -> 
    eq_context_upto Σ Re' Rle' Γ Δ.
  Proof.
     induction 1; constructor; auto.
     eapply compare_decls_impl; eauto.
     intros x y h.
     eapply eq_term_upto_univ_impl. 5:eauto. all:try tc || auto.
     intros x y h.
     eapply eq_term_upto_univ_impl. 5:eauto. all:try tc || auto.
     transitivity Re'; auto.
  Qed.

  Lemma eq_leq_context_upto Γ Δ : 
    eq_context_upto Σ (eq_universe Σ) (eq_universe Σ) Γ Δ ->
    eq_context_upto Σ (eq_universe Σ) (leq_universe Σ) Γ Δ.
  Proof. apply eq_context_upto_impl. Qed.

  Lemma cumul_eq_context_upto {Γ Δ T U} :
    eq_context_upto Σ (eq_universe Σ) (eq_universe Σ) Γ Δ ->
    Σ ;;; Γ |- T <= U ->
    Σ ;;; Δ |- T <= U.
  Proof.
    intros eqctx cum. symmetry in eqctx.
    apply eq_leq_context_upto in eqctx.
    eapply cumul_leq_context_upto; eauto.
  Qed.

  Lemma equality_eq_context_upto {le Γ Δ T U} :
    eq_context_upto Σ (eq_universe Σ) (eq_universe Σ) Γ Δ ->
    is_closed_context Δ ->
    Σ ;;; Γ ⊢ T ≤[le] U ->
    Σ ;;; Δ ⊢ T ≤[le] U.
  Proof.
    intros eqctx cl cum. symmetry in eqctx.
    eapply (equality_compare_context (le:=false)) in cum; tea.
  Qed.

  Lemma conv_alt_red_ctx {Γ : closed_context} {Γ'} {T U : open_term Γ} :
    Σ ;;; Γ |- T = U ->
    @red_ctx Σ Γ Γ' ->
    Σ ;;; Γ' |- T = U.
  Proof.
    intros H Hctx.
    eapply conv_alt_red in H. apply conv_alt_red.
    destruct H as [T' [U' [[redv redv'] leqvv']]].
    destruct (red_red_ctx _ _ redv Hctx) as [Tj [redTj redT'j]].
    destruct (red_red_ctx _ _ redv' Hctx) as [Uj [redUUj redU'j]].
    destruct (fill_eq (Γ := inj_closed Γ' byfvs) (t := inj_open T' byfvs) (u := inj_open U' byfvs) leqvv' redT'j redU'j) as [Tnf [Unf [[redTnf redUnf] eqnf]]].
    exists Tnf, Unf; intuition eauto.
    now transitivity Tj.
    now transitivity Uj.
  Qed.

  Lemma conv_alt_red_ctx_inv {Γ Γ' : closed_context} {T U : open_term Γ} :
    Σ ;;; Γ |- T = U ->
    red_ctx Σ Γ' Γ ->
    Σ ;;; Γ' |- T = U.
  Proof.
    intros H Hctx.
    apply conv_alt_red in H as [v [v' [[redl redr] leq]]].
    pose proof (red_red_ctx_inv redl Hctx).
    pose proof (red_red_ctx_inv redr Hctx).
    apply conv_alt_red.
    exists v, v'.
    split. pcuic. auto.
  Qed.
  
  Lemma cumul_alt_red_ctx {Γ : closed_context} {Γ'} {T U : open_term Γ} :
    Σ ;;; Γ |- T <= U ->
    @red_ctx Σ Γ Γ' ->
    Σ ;;; Γ' |- T <= U.
  Proof.
    intros H Hctx.
    eapply cumul_alt in H. apply cumul_alt.
    destruct H as [T' [U' [[redv redv'] leqvv']]].
    destruct (red_red_ctx _ _ redv Hctx) as [Tj [redTj redT'j]].
    destruct (red_red_ctx _ _ redv' Hctx) as [Uj [redUUj redU'j]].
    destruct (fill_le (Γ := inj_closed Γ' byfvs) (t := inj_open T' byfvs) (u := inj_open U' byfvs) leqvv' redT'j redU'j) as [Tnf [Unf [[redTnf redUnf] eqnf]]].
    exists Tnf, Unf; intuition eauto.
    now transitivity Tj.
    now transitivity Uj.
  Qed.

  Lemma cumul_alt_red_ctx_inv {Γ Γ' : closed_context} {T U : open_term Γ} :
    Σ ;;; Γ |- T <= U ->
    red_ctx Σ Γ' Γ ->
    Σ ;;; Γ' |- T <= U.
  Proof.
    intros H Hctx.
    apply cumul_alt in H as [v [v' [[redl redr] leq]]].
    pose proof (red_red_ctx_inv redl Hctx).
    pose proof (red_red_ctx_inv redr Hctx).
    apply cumul_alt.
    exists v, v'.
    split. pcuic. auto.
  Qed.

  Lemma equality_red_ctx_inv {le Γ Γ'} {T U} :
    Σ ⊢ Γ' ⇝ Γ ->
    Σ ;;; Γ ⊢ T ≤[le] U ->
    Σ ;;; Γ' ⊢ T ≤[le] U.
  Proof.
    intros Hctx H.
    apply equality_red in H as [v [v' [redl redr leq]]].
    epose proof (red_red_ctx_inv' Hctx redl). 
    epose proof (red_red_ctx_inv' Hctx redr). 
    apply equality_red.
    now exists v, v'.
  Qed.

  Lemma closed_red_refl Γ t : 
    is_closed_context Γ ->
    is_open_term Γ t ->
    Σ ;;; Γ ⊢ t ⇝ t.
  Proof.
    now constructor.
  Qed.
  
  Lemma red_decl_refl Γ d : 
    is_closed_context Γ ->
    ws_decl Γ d ->
    All_decls (closed_red Σ Γ) d d.
  Proof.
    destruct d as [na [b|] ty] => [onΓ /andP[] /=|]; constructor.
    all:split; eauto with fvs.
  Qed.

  Lemma closed_red_ctx_refl Γ : is_closed_context Γ -> Σ ⊢ Γ ⇝ Γ.
  Proof.
    move/on_free_vars_ctx_All_fold => a.
    apply: All_fold_All2_fold_impl; tea; clear => Γ d H IH; cbn.
    apply red_decl_refl.
    now apply on_free_vars_ctx_All_fold.
  Qed.

  Lemma context_equality_red {le} {Γ Γ' : context} :
    context_equality le Σ Γ Γ' ->
    ∑ Δ Δ', Σ ⊢ Γ ⇝ Δ × Σ ⊢ Γ' ⇝ Δ' ×
      eq_context_upto Σ (eq_universe Σ) (compare_universe le Σ) Δ Δ'.
  Proof.
    intros Hctx.
    induction Hctx.
    - exists [], []; intuition pcuic.
    - destruct IHHctx as (Δ & Δ' & redl & redr & eq).
      destruct p.
      { apply (equality_red_ctx redl) in eqt.
        eapply equality_red in eqt as (v & v' & [tv tv' com]).
        destruct (closed_red_eq_context_upto_l (le:=le) (Δ := Δ') byfvs tv' eq) as [t'' [redt'' eq']].
        exists (vass na v :: Δ), (vass na' t'' :: Δ').
        intuition auto. constructor; auto. constructor; auto.
        eapply red_red_ctx_inv'; tea.
        constructor; auto. econstructor.
        eapply red_red_ctx_inv'; tea.
        constructor => //. constructor; auto.
        destruct le; cbn in *.
        * transitivity v' => //. now eapply eq_term_leq_term.
        * transitivity v' => //. }
      { apply (equality_red_ctx redl) in eqb.
        eapply equality_red in eqb as (v & v' & [tv tv' com]).
        destruct (closed_red_eq_context_upto_l (le:=le) (Δ := Δ') byfvs tv' eq) as [t'' [redt'' eq']].
        apply (equality_red_ctx redl) in eqt.
        eapply equality_red in eqt as (v0 & v0' & [tv0 tv0' com0]).
        destruct (closed_red_eq_context_upto_l (le:=le) (Δ := Δ') byfvs tv0' eq) as [t0'' [redt0'' eq0']].
        exists (vdef na v v0 :: Δ), (vdef na' t'' t0'' :: Δ').
        intuition auto. constructor; auto. constructor; auto.
        1-2:eapply red_red_ctx_inv'; tea.
        constructor; auto. econstructor; eapply red_red_ctx_inv'; tea.
        constructor => //. constructor; auto.
        cbn in *. transitivity v' => //.
        destruct le; cbn in *.
        * transitivity v0' => //. now eapply eq_term_leq_term.
        * transitivity v0' => //. }
  Qed.

  Lemma equality_equality_ctx {le le'} {Γ Γ'} {T U} :
    Σ ⊢ Γ' ≤[le'] Γ ->
    Σ ;;; Γ ⊢ T ≤[le] U ->
    Σ ;;; Γ' ⊢ T ≤[le] U.
  Proof.
    intros Hctx H.
    apply context_equality_red in Hctx => //.
    destruct Hctx as [Δ [Δ' [l [r elr]]]].
    eapply (equality_red_ctx r) in H.
    destruct le'; cbn in *.
    - eapply (equality_compare_context (le:=true) elr) in H. 2:eauto with fvs.
      now eapply (equality_red_ctx_inv l) in H.
    - eapply (equality_eq_context_upto (symmetry elr)) in H. 2:eauto with fvs.
      now eapply (equality_red_ctx_inv l) in H.
  Qed.

  #[global]
  Instance conv_context_sym : Symmetric (context_equality false Σ).
  Proof.
    intros Γ Γ' conv.
    eapply All2_fold_sym; tea.
    clear Γ Γ' conv. intros Γ Γ' d d' H IH []; constructor; auto.
    now symmetry.
    eapply equality_equality_ctx; tea. now symmetry.
    now symmetry.
    eapply equality_equality_ctx; tea. now symmetry.
    eapply equality_equality_ctx; tea. now symmetry.
  Qed.

  Lemma equality_eq_le {Γ t u} : 
    Σ ;;; Γ ⊢ t = u -> Σ ;;; Γ ⊢ t ≤ u.
  Proof.
    induction 1.
    - constructor; eauto.
      now eapply eq_term_leq_term.
    - econstructor 2; eauto.
    - econstructor 3; eauto.
  Qed.
  Hint Resolve equality_eq_le : pcuic.

  Lemma conv_cumul_context {Γ Δ} : 
    Σ ⊢ Γ ≤[false] Δ -> Σ ⊢ Γ ≤[true] Δ.
  Proof.
    induction 1; constructor; auto.
    eapply conv_context_sym in X.
    depelim p; constructor; auto. 
    - now apply equality_eq_le.
    - now apply equality_eq_le.
  Qed.
  Hint Resolve conv_cumul_context : pcuic.

  (** This is provable as conversion is not relying on types of variables,
      and bodies of let-ins are convertible even for context cumulativity. *)

  Local Remark equality_equality_ctx_inv {le le'} {Γ Γ'} {T U} :
    Σ ⊢ Γ ≤[le'] Γ' ->
    Σ ;;; Γ ⊢ T ≤[le] U ->
    Σ ;;; Γ' ⊢ T ≤[le] U.
  Proof.
    intros Hctx H.
    apply context_equality_red in Hctx => //.
    destruct Hctx as [Δ [Δ' [l [r elr]]]].
    eapply (equality_red_ctx_inv r).
    destruct le'; cbn in *.
    - eapply (equality_red_ctx l) in H.
      eapply (equality_compare_context_inv (le:=true) elr) in H => //. eauto with fvs.
    - eapply (equality_red_ctx l) in H.
      eapply (equality_compare_context_inv (le:=false) elr) in H => //. eauto with fvs.
  Qed.

  Lemma equality_open_decls_equality_ctx {le le'} {Γ Γ'} {d d'} :
    Σ ⊢ Γ' ≤[le'] Γ ->
    equality_open_decls le Σ Γ d d' ->
    equality_open_decls le Σ Γ' d d'.
  Proof.
    intros Hctx H.
    destruct H; constructor; auto; eapply equality_equality_ctx; tea.
  Qed.

  #[global]
  Instance context_equality_trans le : Transitive (context_equality le Σ).
  Proof.
    eapply All2_fold_trans.
    intros.
    etransitivity; tea.
    now eapply (equality_open_decls_equality_ctx X).
  Qed.

  #[global]
  Instance conv_context_trans : Transitive (context_equality false Σ).
  Proof. apply context_equality_trans. Qed.

  #[global]
  Instance cumul_context_trans : Transitive (context_equality true Σ).
  Proof. apply context_equality_trans. Qed.
  
End ContextConversion.

#[global] Hint Resolve isType_open wf_local_closed_context : fvs.
#[global] Hint Resolve conv_ctx_refl' : pcuic.
#[global] Hint Constructors conv_decls : pcuic.

Lemma eq_context_upto_conv_context {cf:checker_flags} (Σ : global_env_ext) Re :
  RelationClasses.subrelation Re (eq_universe Σ) ->
  subrelation (eq_context_upto Σ Re Re) (fun Γ Γ' => conv_context Σ Γ Γ').
Proof.
  intros HRe Γ Δ h. induction h.
  - constructor.
  - constructor; tas.
    depelim p; constructor; auto; constructor; tas;
    eapply eq_term_upto_univ_impl; tea; auto.
Qed.

Lemma eq_context_upto_cumul_context {cf:checker_flags} (Σ : global_env_ext) Re Rle :
  RelationClasses.subrelation Re (eq_universe Σ) ->
  RelationClasses.subrelation Rle (leq_universe Σ) ->
  RelationClasses.subrelation Re Rle ->
  subrelation (eq_context_upto Σ Re Rle) (fun Γ Γ' => cumul_context Σ Γ Γ').
Proof.
  intros HRe HRle hR Γ Δ h. induction h.
  - constructor.
  - constructor; tas.
    depelim p; constructor; auto; constructor; tas.
    eapply eq_term_upto_univ_impl. 5:eauto. all:tea. 
    now transitivity Rle. auto.
    eapply eq_term_upto_univ_impl; eauto.
    eapply eq_term_upto_univ_impl. 5:eauto. all:tea. 
    now transitivity Rle. auto.
Qed.

#[global]
Instance eq_subrel_eq_univ {cf:checker_flags} Σ : RelationClasses.subrelation eq (eq_universe Σ).
Proof. intros x y []. reflexivity. Qed.

Lemma eq_context_upto_empty_conv_context {cf:checker_flags} (Σ : global_env_ext) :
  subrelation (eq_context_upto [] eq eq) (fun Γ Γ' => conv_context Σ Γ Γ').
Proof.
  intros Γ Δ h. induction h.
  - constructor.
  - constructor; tas.
    depelim p; constructor; auto; constructor.
    all:eapply eq_term_upto_univ_empty_impl; tea; try typeclasses eauto.
Qed.

Lemma eq_context_upto_univ_conv_context {cf:checker_flags} {Σ : global_env_ext} Γ Δ :
    eq_context_upto Σ.1 (eq_universe Σ) (eq_universe Σ) Γ Δ ->
    conv_context Σ Γ Δ.
Proof.
  intros h. eapply eq_context_upto_conv_context; tea.
  reflexivity.
Qed.

Lemma eq_context_upto_univ_cumul_context {cf:checker_flags} {Σ : global_env_ext} Γ Δ :
    eq_context_upto Σ.1 (eq_universe Σ) (leq_universe Σ) Γ Δ ->
    cumul_context Σ Γ Δ.
Proof.
  intros h. eapply eq_context_upto_cumul_context; tea.
  reflexivity. tc. tc.
Qed.

Lemma conv_context_app_same {cf:checker_flags} Σ Γ Γ' Δ :
  conv_context Σ Γ Γ' ->
  conv_context Σ (Γ ,,, Δ) (Γ' ,,, Δ).
Proof.
  intros HΔ.
  induction Δ; auto.
  destruct a as [na [b|] ty]; constructor; auto;
    constructor; reflexivity.
Qed.

Lemma cumul_context_app_same {cf:checker_flags} Σ Γ Γ' Δ :
  cumul_context Σ Γ Γ' ->
  cumul_context Σ (Γ ,,, Δ) (Γ' ,,, Δ).
Proof.
  intros HΔ.
  induction Δ; auto.
  destruct a as [na [b|] ty]; constructor; auto;
    constructor; reflexivity.
Qed.

#[global] Hint Extern 4 (eq_term_upto_univ _ _ _ _ _) => reflexivity : pcuic.

Axiom fix_guard_context_cumulativity : forall {cf:checker_flags} Σ Γ Γ' mfix,
  cumul_context Σ Γ' Γ ->
  fix_guard Σ Γ mfix ->
  fix_guard Σ Γ' mfix.

Axiom cofix_guard_context_cumulativity : forall {cf:checker_flags} Σ Γ Γ' mfix,
  cumul_context Σ Γ' Γ ->
  cofix_guard Σ Γ mfix ->
  cofix_guard Σ Γ' mfix.

(* Definition on_decl (P : context -> term -> term -> Type)
             (Γ : context) (t : term) (t' : option term) :=
    match t' with
    | Some (b, b') => (P Γ b b' * P Γ Γ' t t')%type
    | None => P Γ Γ' t t'
    end. *)
Definition on_local_decl (P : context -> term -> option term -> Type) (Γ : context) (d : context_decl) :=
  match decl_body d with
  | Some b => P Γ b (Some (decl_type d)) * P Γ (decl_type d) None
  | None => P Γ (decl_type d) None
  end.

Lemma nth_error_All_local_env {P Γ n} (isdecl : n < #|Γ|) :
  All_local_env P Γ ->
  on_some (on_local_decl P (skipn (S n) Γ)) (nth_error Γ n).
Proof.
  induction 1 in n, isdecl |- *. red; simpl.
  - destruct n; simpl; inv isdecl.
  - destruct n. red; simpl. red. simpl. apply t0.
    simpl. apply IHX. simpl in isdecl. lia.
  - destruct n; simpl in *.
    * rewrite skipn_S skipn_0. red; cbn.
      split; auto.
    * rewrite !skipn_S. apply IHX. lia.
Qed.

Lemma context_cumulativity_wf_app {cf:checker_flags} Σ Γ Γ' Δ : 
  cumul_context Σ Γ' Γ ->
  wf_local Σ Γ' ->
    All_local_env
       (lift_typing
          (fun (Σ : global_env_ext) (Γ : context) (t T : term) =>
           forall Γ' : context,
           cumul_context Σ Γ' Γ -> wf_local Σ Γ' -> Σ;;; Γ' |- t : T) Σ)
       (Γ,,, Δ) ->
  wf_local Σ (Γ' ,,, Δ).
Proof.
  intros.
  eapply wf_local_app => //.
  eapply All_local_env_app_inv in X1 as [].
  eapply All_local_env_impl_ind; tea => /=.
  rewrite /lift_typing => Γ'' t' [t wf IH|wf [s IH]]; try exists s; eauto; red.
  eapply IH. eapply All2_fold_app => //.
  eapply All2_fold_refl. intros. eapply cumul_decls_refl.
  eapply All_local_env_app; split; auto.
  eapply IH. 
  eapply All2_fold_app => //.
  eapply All2_fold_refl. intros. eapply cumul_decls_refl.
  eapply All_local_env_app; split; auto.
Qed.

Lemma is_closed_context_cumul_app Γ Δ Γ' : 
  is_closed_context (Γ ,,, Δ) ->
  is_closed_context Γ' ->
  #|Γ| = #|Γ'| ->
  is_closed_context (Γ' ,,, Δ).
Proof.
  rewrite !on_free_vars_ctx_app => /andP[] onΓ onΔ onΓ' <-.
  now rewrite onΓ' onΔ.
Qed.

Lemma on_free_vars_decl_eq n m d :
  on_free_vars_decl (shiftnP n xpred0) d ->
  n = m ->
  on_free_vars_decl (shiftnP m xpred0) d.
Proof.
  now intros o ->.
Qed.

#[global] Hint Extern 4 (is_true (on_free_vars_decl (shiftnP _ xpred0) _)) =>
  eapply on_free_vars_decl_eq; [eassumption|len; lia] : fvs.

Lemma context_equality_false_forget {cf} {Σ} {wfΣ : wf Σ} {Γ Γ'} : 
  context_equality false Σ Γ Γ' -> conv_context Σ Γ Γ'.
Proof.
  apply: context_equality_forget.
Qed.

Lemma context_equality_true_forget {cf} {Σ} {wfΣ : wf Σ} {Γ Γ'} : 
  context_equality true Σ Γ Γ' -> cumul_context Σ Γ Γ'.
Proof.
  apply: context_equality_forget.
Qed.

Ltac exass H := 
  match goal with
  |- ∑ x : ?A, _ => 
    assert (H : A); [idtac|exists H]
  end.

Lemma into_context_equality {cf:checker_flags} {le : bool} {Σ : global_env_ext} {wfΣ : wf Σ} 
  {Γ Γ' : context} :
  is_closed_context Γ ->
  is_closed_context Γ' ->
  (if le then cumul_context Σ Γ Γ' else conv_context Σ Γ Γ') ->
  context_equality le Σ Γ Γ'.
Proof.
  move/on_free_vars_ctx_All_fold => onΓ.
  move/on_free_vars_ctx_All_fold => onΓ'.
  destruct le.
  { intros cum.
    eapply All2_fold_All_fold_mix in cum; tea.
    eapply All2_fold_impl_ind; tea. clear -wfΣ.
    cbn; intros. red.
    eapply All2_fold_All_fold_mix_inv in X as [cum [onΓ onΔ]].
    move/on_free_vars_ctx_All_fold: onΓ => onΓ.
    move/on_free_vars_ctx_All_fold: onΔ => onΓ'.
    destruct X1 as [wsd [wsd' cumd]].
    eapply into_equality_open_decls; cbn; tea.
    rewrite (All2_fold_length X0) //. } 
  { intros cum.
    eapply All2_fold_All_fold_mix in cum; tea.
    eapply All2_fold_impl_ind; tea. clear -wfΣ.
    cbn; intros. red.
    eapply All2_fold_All_fold_mix_inv in X as [cum [onΓ onΔ]].
    move/on_free_vars_ctx_All_fold: onΓ => onΓ.
    move/on_free_vars_ctx_All_fold: onΔ => onΓ'.
    destruct X1 as [wsd [wsd' cumd]].
    eapply into_equality_open_decls; cbn; tea.
    rewrite (All2_fold_length X0) //. }
Qed.

Lemma context_equality_refl {cf} {Σ} {wfΣ : wf Σ} {le} {Γ : context} :
  is_closed_context Γ -> Σ ⊢ Γ ≤[le] Γ.
Proof.
  move/on_free_vars_ctx_All_fold.
  induction 1; constructor; auto.
  eapply (into_equality_open_decls _ Γ); tea; eauto with fvs.
  destruct le; cbn; reflexivity.
Qed.

Lemma context_equality_app_same {cf} {Σ} {wfΣ : wf Σ} {le} {Γ Γ' Δ : context} :
  is_closed_context (Γ ,,, Δ) ->
  Σ ⊢ Γ ≤[le] Γ' -> Σ ⊢ Γ,,, Δ ≤[le] Γ',,, Δ.
Proof.
  move=> iscl cum.
  eapply into_context_equality => //.
  eapply is_closed_context_cumul_app; tea; eauto with fvs.
  now rewrite (All2_fold_length cum).
  destruct le. apply cumul_context_app_same.
  now apply context_equality_true_forget.
  apply conv_context_app_same.
  now apply context_equality_false_forget.
Qed.

Lemma context_cumulativity_app {cf:checker_flags} {Σ : global_env_ext} {wfΣ : wf Σ} {le Γ Γ' Δ Δ'} : 
  Σ ⊢ Γ' ≤ Γ ->
  Σ ⊢ Γ ,,, Δ ≤[le] Γ ,,, Δ' ->
  Σ ⊢ Γ' ,,, Δ ≤[le] Γ' ,,, Δ'.
Proof.
  intros cum conv.
  pose proof (length_of conv). len in H.
  eapply All2_fold_app; eauto.
  eapply context_equality_refl; cbn; eauto with fvs.
  eapply All2_fold_app_inv in conv as []. 2:lia.
  eapply All2_fold_impl_ind; tea.
  intros. simpl in X1.
  pose proof (All2_fold_length cum).
  eapply equality_open_decls_equality_ctx; tea.
  eapply context_equality_app_same. 
  { pose proof (context_equality_closed_left cum).
    eapply (equality_open_decls_inv _ (Γ':=Γ' ,,, Γ0)) in X1 as [isc _]; tea.
    eapply is_closed_context_cumul_app; tea; try lia. }
  exact cum.
Qed.

Notation open_context Γ := (ws_context (shiftnP #|Γ| xpred0)).

Lemma weakening_cumul0 {cf:checker_flags} {Σ} {wfΣ : wf Σ} {Γ : closed_context} {Γ'' : open_context Γ}
  {M N : open_term Γ} n :
  n = #|Γ''| ->
  Σ ;;; Γ |- M <= N ->
  Σ ;;; Γ ,,, Γ'' |- lift0 n M <= lift0 n N.
Proof. intros; subst. apply (weakening_cumul (Γ':= [])); tea; eauto with fvs. Qed.

Lemma split_closed_context {Γ : context} (n : nat) : 
  is_closed_context Γ ->
  n <= #|Γ| ->
  ∑ (Δ : closed_context) (Δ' : open_context Δ), 
    [× Δ = skipn n Γ :> context, Δ' = firstn n Γ :> context,
       Γ = Δ ,,, Δ' & n = #|Δ'|].
Proof.
  rewrite -{1}(firstn_skipn n Γ).
  rewrite on_free_vars_ctx_app => /andP[] sk fi.
  exists (exist (skipn n Γ) sk).
  exists (exist (firstn n Γ) fi). split; auto.
  cbn. now rewrite firstn_skipn. cbn.
  rewrite List.firstn_length. lia.
Qed.

Lemma nth_error_closed_context {Γ n d} :
  is_closed_context Γ ->  
  nth_error Γ n = Some d ->
  ws_decl (skipn (S n) Γ) d.
Proof.
  rewrite -on_free_vars_ctx_on_ctx_free_vars -[shiftnP _ _]addnP0 => hΔ' hnth.
  eapply nth_error_on_free_vars_ctx in hΔ'; tea.
  2:{ rewrite /shiftnP /= orb_false_r. apply Nat.ltb_lt. now apply nth_error_Some_length in hnth. }
  rewrite List.skipn_length.
  eapply on_free_vars_decl_impl; tea.
  intros i.
  rewrite /= /addnP /shiftnP /= !orb_false_r => /Nat.ltb_lt hl.
  apply Nat.ltb_lt. lia.
Qed.

Lemma on_free_vars_decl_lift (p : nat -> bool) n k t : 
  on_free_vars_decl (strengthenP k n p) (lift_decl n k t) = on_free_vars_decl p t.
Proof.
  rewrite /on_free_vars_decl /test_decl /=.
  f_equal. destruct (decl_body t) => /= //.
  all:now rewrite on_free_vars_lift.
Qed.

Lemma on_free_vars_decl_lift_impl (p : nat -> bool) n k d : 
  on_free_vars_decl (shiftnP k p) d ->
  on_free_vars_decl (shiftnP (n + k) p) (lift_decl n k d).
Proof.
  rewrite /on_free_vars_decl /test_decl /= => /andP[].
  destruct (decl_body d) => /= //.
  move/(on_free_vars_lift_impl _ n) ->.
  move/(on_free_vars_lift_impl _ n) -> => //.
  move=> _.
  move/(on_free_vars_lift_impl _ n) -> => //.
Qed.

Lemma nth_error_Some_add {A} (l : list A) (n : nat) (x : A) : 
  (nth_error l n = Some x) <~> 
  (n < #|l| × nth_error l n = Some x).
Proof.
  split. intros hnth; split => //.
  now eapply nth_error_Some_length in hnth.
  now intros [].
Qed.

Lemma nth_error_closed_context_lift {Γ n d} :
  is_closed_context Γ ->  
  nth_error Γ n = Some d ->
  ws_decl Γ (lift_decl (S n) 0 d).
Proof.
  move=> cl /nth_error_Some_add[] hn /(nth_error_closed_context cl).
  rewrite -(on_free_vars_decl_lift _ (S n) 0 d).
  apply: on_free_vars_decl_impl => i.
  rewrite /strengthenP /= /shiftnP !orb_false_r List.skipn_length.
  repeat PCUICSigmaCalculus.nat_compare_specs => //.
Qed.

Lemma wt_cum_equality {cf} {Σ} {wfΣ : wf Σ} {Γ : context} {t A B : term} {s} :
  Σ ;;; Γ |- t : A ->
  Σ ;;; Γ |- B : tSort s ->
  Σ ;;; Γ |- A <= B ->
  Σ ;;; Γ ⊢ A ≤ B. 
Proof.
  move=> a; move: a (typing_wf_local a).
  move/PCUICClosed.type_closed/(@closedn_on_free_vars xpred0) => clA.
  move/wf_local_closed_context => clΓ.
  move/PCUICClosed.subject_closed/(@closedn_on_free_vars xpred0) => clB cum.
  now apply into_equality.
Qed.

Lemma wt_cum_context_equality {cf} {Σ} {wfΣ : wf Σ} {Γ Δ : context} le :
  wf_local Σ Γ ->
  wf_local Σ Δ ->
  (if le then cumul_context Σ Γ Δ else conv_context Σ Γ Δ) ->
  Σ ⊢ Γ ≤[le] Δ. 
Proof.
  move/wf_local_closed_context => wfΓ.
  move/wf_local_closed_context => wfΔ.
  now eapply into_context_equality.
Qed.

Lemma All2_conv_over_refl {cf} {Σ} {Γ Γ' Δ} : 
  All2_fold (All_over (conv_decls Σ) Γ Γ') Δ Δ.
Proof.
  eapply All2_fold_refl. intros ? ?; reflexivity.
Qed.

Lemma All2_cumul_over_refl {cf} {Σ} {Γ Γ' Δ} : 
  All2_fold (All_over (cumul_decls Σ) Γ Γ') Δ Δ.
Proof.
  eapply All2_fold_refl. intros ? ?; reflexivity.
Qed.

Lemma context_cumulativity_prop {cf:checker_flags} :
  env_prop
    (fun Σ Γ t T =>
       forall Γ', cumul_context Σ Γ' Γ -> wf_local Σ Γ' -> Σ ;;; Γ' |- t : T)
    (fun Σ Γ => 
    All_local_env
      (lift_typing (fun Σ (Γ : context) (t T : term) =>
        forall Γ' : context, cumul_context Σ Γ' Γ -> wf_local Σ Γ' -> Σ;;; Γ' |- t : T) Σ) Γ).
Proof.
  apply typing_ind_env; intros Σ wfΣ Γ wfΓ; intros **; rename_all_hyps;
    try solve [econstructor; eauto].

  - induction X; constructor; auto.
    destruct tu as [s Hs]. exists s; eauto.
    destruct tu as [s Hs]. exists s; eauto.

  - pose proof heq_nth_error.
    eapply (All2_fold_nth_r X0) in H as [d' [Hnth [Hrel Hconv]]].
    unshelve eapply nth_error_All_local_env in X; tea. 2:eapply nth_error_Some_length in heq_nth_error; lia.
    rewrite heq_nth_error /= in X.
    destruct decl as [na [b|] ty] => /=.
    + red in X. cbn in X. destruct X as [Hb Hty].
      destruct Hty as [s Hty]. specialize (Hty _ Hrel).
      forward Hty by now eapply All_local_env_skipn.
      eapply type_Cumul with _ s.
      * econstructor. auto. eauto.
      * rewrite -(firstn_skipn (S n) Γ').
        change (tSort s) with (lift0 (S n) (tSort s)).
        eapply weakening_length. auto.
        rewrite firstn_length_le. eapply nth_error_Some_length in Hnth. lia. auto.
        now rewrite /app_context firstn_skipn.
        assumption.
      * depelim Hconv; simpl in *.
        destruct (split_closed_context (S n) (wf_local_closed_context X1)) as [Δ [Δ' [eqΔ eqΔ' -> hn]]].
        eapply nth_error_Some_length in Hnth. lia.
        rewrite -eqΔ in Hty, Hrel.
        rewrite -eqΔ in c0, c.
        assert (is_open_term Δ T).
        { eapply nth_error_closed_context in Hnth. 2:eauto with fvs.
          rewrite -eqΔ in Hnth. now move/andP: Hnth => []. }
        eapply PCUICClosed.subject_closed in Hty.
        eapply (@closedn_on_free_vars xpred0) in Hty.
        eapply (weakening_cumul0 (Γ := Δ) (Γ'' := Δ') (M := exist T H) (N := exist ty Hty)); cbn. lia.
        exact c0.
    + cbn in X. destruct X as [s ondecl].
      specialize (ondecl _ Hrel).
      depelim Hconv.
      forward ondecl by now eapply All_local_env_skipn.
      eapply type_Cumul with _ s.
      * econstructor. auto. eauto.
      * rewrite -(firstn_skipn (S n) Γ').
        change (tSort s) with (lift0 (S n) (tSort s)).
        eapply weakening_length. auto.
        rewrite firstn_length_le. eapply nth_error_Some_length in Hnth. lia. auto.
        now rewrite /app_context firstn_skipn.
        assumption.
      * destruct (split_closed_context (S n) (wf_local_closed_context X1)) as [Δ [Δ' [eqΔ eqΔ' -> hn]]].
        eapply nth_error_Some_length in Hnth. lia.
        rewrite -eqΔ in ondecl, Hrel.
        rewrite -eqΔ in c.
        assert (is_open_term Δ T).
        { rewrite nth_error_app_lt in Hnth. rewrite -hn. lia.
          destruct Δ' as [Δ' hΔ']. cbn in *.
          move: hΔ'.
          rewrite -on_free_vars_ctx_on_ctx_free_vars -[shiftnP _ _]addnP0 => hΔ'.
          eapply nth_error_on_free_vars_ctx in hΔ'; tea.
          2:{ rewrite shiftnP_add /shiftnP /= orb_false_r. apply Nat.ltb_lt. lia. }
          rewrite /test_decl /= in hΔ'. move: hΔ'.
          now rewrite hn addnP_shiftnP. }
        eapply PCUICClosed.subject_closed in ondecl.
        eapply (@closedn_on_free_vars xpred0) in ondecl.
        eapply (weakening_cumul0 (Γ := Δ) (Γ'' := Δ') (M := exist T H) (N := exist ty ondecl)); cbn. lia.
        exact c.
  - constructor; pcuic.
    eapply forall_Γ'0. repeat (constructor; pcuic).
    constructor; auto. red. eexists; eapply forall_Γ'; auto.
  - econstructor; pcuic.
    eapply forall_Γ'0; repeat (constructor; pcuic).
  - econstructor; pcuic.
    eapply forall_Γ'1; repeat (constructor; pcuic).
  - econstructor; eauto.
    * eapply context_cumulativity_wf_app; tea.
    * eapply IHp0. rewrite /predctx.
      eapply All2_fold_app => //.
      eapply All2_fold_refl. intros ? ?; reflexivity.
      eapply context_cumulativity_wf_app; tea.
    * revert X6.
      clear -Γ' X10 X11. induction 1; constructor; eauto.
    * eapply All2i_impl; tea => i cdecl br. cbv beta.
      set (brctxty := case_branch_type _ _ _ _ _ _ _ _). cbn.
      move=> [] hbctx [] ihbctxty [] hbody [] IHbody [] hbty IHbty.
      intuition eauto; solve_all.
      eapply context_cumulativity_wf_app; tea.
      eapply IHbody. eapply All2_fold_app => //. apply All2_cumul_over_refl.
      eauto using context_cumulativity_app, context_cumulativity_wf_app.
      eapply IHbty.
      eapply All2_fold_app => //. apply All2_cumul_over_refl.
      eapply context_cumulativity_wf_app; tea.
  - econstructor. eapply fix_guard_context_cumulativity; eauto.
    all:pcuic.
    eapply (All_impl X0).
    intros x [s [Hs IH]].
    exists s; eauto.
    eapply (All_impl X1).
    intros x [Hs IH].
    eapply IH.
    now apply cumul_context_app_same.
    eapply (All_mfix_wf); auto.
    apply (All_impl X0); simpl.
    intros x' [s [Hs' IH']]. exists s.
    eapply IH'; auto.
  - econstructor.
    eapply cofix_guard_context_cumulativity; eauto.
    all:pcuic.
    + eapply (All_impl X0).
      intros x [s [Hs IH]].
      exists s; eauto.
    + eapply (All_impl X1).
      intros x [Hs IH].
      eapply IH.
      now apply cumul_context_app_same.
      eapply (All_mfix_wf); auto.
      apply (All_impl X0); simpl.
      intros x' [s [Hs' IH']]. exists s.
      eapply IH'; auto.
    
  - econstructor; eauto.
    eapply wt_cum_equality in X4; tea.
    apply (wt_cum_context_equality true) in X5; tea.
    eapply (equality_equality_ctx X5) in X4.
    now eapply equality_forget in X4. 
Qed.

Lemma closed_context_cumul_cumul {cf} {Σ} {wfΣ : wf Σ} {Γ Γ'} : 
  Σ ⊢ Γ ≤ Γ' -> cumul_context Σ Γ Γ'.
Proof.
  now move/context_equality_forget.
Qed.
#[global] Hint Resolve closed_context_cumul_cumul : pcuic.

Lemma closed_context_conv_conv {cf} {Σ} {wfΣ : wf Σ} {Γ Γ'} : 
  Σ ⊢ Γ = Γ' -> conv_context Σ Γ Γ'.
Proof.
  now move/context_equality_forget.
Qed.
#[global] Hint Resolve closed_context_conv_conv : pcuic.

Lemma closed_context_cumulativity {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} Γ {le t T Γ'} :
  Σ ;;; Γ |- t : T ->
  wf_local Σ Γ' ->
  Σ ⊢ Γ' ≤[le] Γ ->
  Σ ;;; Γ' |- t : T.
Proof.
  intros h hΓ' e.
  pose proof (context_equality_forget e).
  destruct le.
  eapply context_cumulativity_prop; eauto.
  eapply context_cumulativity_prop; eauto.
  eapply conv_cumul_context in e; tea.
  eapply (context_equality_forget e).
Qed.

Lemma context_cumulativity {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} Γ {t T Γ'} :
  Σ ;;; Γ |- t : T ->
  wf_local Σ Γ' ->
  cumul_context Σ Γ' Γ ->
  Σ ;;; Γ' |- t : T.
Proof.
  intros h hΓ' e.
  eapply context_cumulativity_prop; eauto.
Qed.

#[global] Hint Resolve wf_local_closed_context : fvs.

Lemma wf_conv_context_closed {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} {Γ Γ'} :
  conv_context Σ Γ Γ' -> 
  wf_local Σ Γ ->
  wf_local Σ Γ' ->
  context_equality false Σ Γ Γ'.
Proof.
  move=> a wf wf'.
  eapply into_context_equality; eauto with fvs.
Qed.

Lemma wf_cumul_context_closed {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} {Γ Γ'} :
  cumul_context Σ Γ Γ' -> 
  wf_local Σ Γ ->
  wf_local Σ Γ' ->
  context_equality true Σ Γ Γ'.
Proof.
  move=> a wf wf'.
  eapply into_context_equality; eauto with fvs.
Qed.

Lemma context_conversion {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} Γ {t T Γ'} :
  Σ ;;; Γ |- t : T ->
  wf_local Σ Γ' ->
  conv_context Σ Γ Γ' ->
  Σ ;;; Γ' |- t : T.
Proof.
  intros h hΓ' e.
  eapply wf_conv_context_closed in e; eauto with fvs pcuic.
  symmetry in e.
  now eapply closed_context_cumulativity in e.
Qed.

(* For ease of application, avoiding to add a call to symmetry *)
Lemma closed_context_conversion {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} Γ {t T Γ'} :
  Σ ;;; Γ |- t : T ->
  wf_local Σ Γ' ->
  Σ ⊢ Γ = Γ' ->
  Σ ;;; Γ' |- t : T.
Proof.
  intros h hΓ' e.
  symmetry in e.
  now eapply closed_context_cumulativity in e.
Qed.
