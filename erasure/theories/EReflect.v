From MetaCoq.Template Require Import utils Reflect.
From MetaCoq.Erasure Require Import EAst EInduction.
From MetaCoq.PCUIC Require Import PCUICReflect PCUICPrimitive.
From Equations Require Import Equations.

Local Ltac finish :=
  let h := fresh "h" in
  right ;
  match goal with
  | e : ?t <> ?u |- _ =>
    intro h ; apply e ; now inversion h
  end.

Local Ltac fcase c :=
  let e := fresh "e" in
  case c ; intro e ; [ subst ; try (left ; reflexivity) | finish ].

Local Ltac term_dec_tac term_dec :=
  repeat match goal with
         | t : term, u : term |- _ => fcase (term_dec t u)
         | n : nat, m : nat |- _ => fcase (Nat.eq_dec n m)
         | i : ident, i' : ident |- _ => fcase (string_dec i i')
         | i : kername, i' : kername |- _ => fcase (kername_eq_dec i i')
         | i : string, i' : kername |- _ => fcase (string_dec i i')
         | n : name, n' : name |- _ => fcase (eq_dec n n')
         | i : prim_val _, i' : prim_val _ |- _ => fcase (eq_dec i i')
         | i : inductive, i' : inductive |- _ => fcase (eq_dec i i')
         | x : inductive * nat, y : inductive * nat |- _ =>
           fcase (eq_dec x y)
         | x : projection, y : projection |- _ => fcase (eq_dec x y)
         end.

Ltac nodec :=
  let bot := fresh "bot" in
  try solve [ constructor ; intro bot ; inversion bot ; subst ; tauto ].

Derive NoConfusion NoConfusionHom for term.

#[global]
Instance EqDec_term : EqDec term.
Proof.
  intro x; induction x using term_forall_list_ind ; intro t ;
    destruct t ; try (right ; discriminate).
  all: term_dec_tac term_dec.
  - left; reflexivity.
  - revert l0. induction X ; intro l0.
    + destruct l0.
      * left. reflexivity.
      * right. discriminate.
    + destruct l0.
      * right. discriminate.
      * destruct (IHX l0) ; nodec.
        destruct (p t) ; nodec.
        subst. left. inversion e. reflexivity.
  - destruct (IHx t) ; nodec.
    subst; left; reflexivity.
  - destruct (IHx1 t1) ; nodec.
    destruct (IHx2 t2) ; nodec.
    subst. left. reflexivity.
  - destruct (IHx1 t1) ; nodec.
    destruct (IHx2 t2) ; nodec.
    subst. left. reflexivity.
  - destruct (IHx t) ; nodec.
    subst. revert l0. clear IHx.
    induction X ; intro l0.
    + destruct l0.
      * left. reflexivity.
      * right. discriminate.
    + destruct l0.
      * right. discriminate.
      * destruct (IHX l0) ; nodec.
        destruct (p (snd p1)) ; nodec.
        destruct (eq_dec (fst x) (fst p1)) ; nodec.
        destruct x, p1.
        left.
        cbn in *. subst. inversion e. reflexivity.
  - destruct (IHx t) ; nodec.
    left. subst. reflexivity.
  - revert m0. induction X ; intro m0.
    + destruct m0.
      * left. reflexivity.
      * right. discriminate.
    + destruct m0.
      * right. discriminate.
      * destruct (p (dbody d)) ; nodec.
        destruct (IHX m0) ; nodec.
        destruct x, d ; subst. cbn in *.
        destruct (eq_dec dname dname0) ; nodec.
        subst. inversion e0. subst.
        destruct (eq_dec rarg rarg0) ; nodec.
        subst. left. reflexivity.
  - revert m0. induction X ; intro m0.
    + destruct m0.
      * left. reflexivity.
      * right. discriminate.
    + destruct m0.
      * right. discriminate.
      * destruct (p (dbody d)) ; nodec.
        destruct (IHX m0) ; nodec.
        destruct x, d ; subst. cbn in *.
        destruct (eq_dec dname dname0) ; nodec.
        subst. inversion e0. subst.
        destruct (eq_dec rarg rarg0) ; nodec.
        subst. left. reflexivity.
Defined.

#[global]
Instance ReflectEq_term : Reflect.ReflectEq _ :=
  @EqDec_ReflectEq _ EqDec_term.

Definition eqb_constant_body (x y : constant_body) :=
  eqb (cst_body x) (cst_body y).

#[global]
Instance reflect_constant_body : ReflectEq constant_body.
Proof.
  refine {| eqb := eqb_constant_body |}.
  intros [] [].
  unfold eqb_constant_body.
  cbn -[eqb].
  finish_reflect.
Defined.

Definition eqb_one_inductive_body (x y : one_inductive_body) :=
  let (n, i, k, c, p) := x in
  let (n', i', k', c', p') := y in
  eqb n n' && eqb i i' && eqb k k' && eqb c c' && eqb p p'.

#[global]
Instance reflect_one_inductive_body : ReflectEq one_inductive_body.
Proof.
  refine {| eqb := eqb_one_inductive_body |}.
  intros [] [].
  unfold eqb_one_inductive_body; finish_reflect.
Defined.

Definition eqb_mutual_inductive_body (x y : mutual_inductive_body) :=
  let (n, b) := x in
  let (n', b') := y in
  eqb n n' && eqb b b'.

#[global]
Instance reflect_mutual_inductive_body : ReflectEq mutual_inductive_body.
Proof.
  refine {| eqb := eqb_mutual_inductive_body |}.
  intros [] [].
  unfold eqb_mutual_inductive_body; finish_reflect.
Defined.

Definition eqb_global_decl x y :=
  match x, y with
  | ConstantDecl cst, ConstantDecl cst' => eqb cst cst'
  | InductiveDecl mib, InductiveDecl mib' => eqb mib mib'
  | _, _ => false
  end.

#[global]
Instance reflect_global_decl : ReflectEq global_decl.
Proof.
  refine {| eqb := eqb_global_decl |}.
  unfold eqb_global_decl.
  intros [] []; finish_reflect.
Defined.
