(* Distributed under the terms of the MIT license. *)
From Coq Require Import FSets ExtrOcamlBasic ExtrOcamlString ExtrOcamlZInt ExtrOCamlFloats ExtrOCamlInt63.
From MetaCoq.Template Require Import utils.

(** * Extraction setup for the erasure phase of template-coq.

    Any extracted code planning to link with the plugin
    should use these same directives for consistency.

    ExtrOCamlInt63 extracts comparison to int (-1, 0, 1), so one might need to adapt code accordingly.
*)

Extract Constant ascii_compare =>
 "fun x y -> match Char.compare x y with 0 -> 0 | x when x < 0 -> -1 | _ -> 1".

(* Ignore [Decimal.int] before the extraction issue is solved:
   https://github.com/coq/coq/issues/7017. *)
Extract Inductive Decimal.int => unit [ "(fun _ -> ())" "(fun _ -> ())" ] "(fun _ _ _ -> assert false)".
Extract Inductive Hexadecimal.int => unit [ "(fun _ -> ())" "(fun _ -> ())" ] "(fun _ _ _ -> assert false)".
Extract Inductive Number.int => unit [ "(fun _ -> ())" "(fun _ -> ())" ] "(fun _ _ _ -> assert false)".

Extraction Blacklist Classes config uGraph Universes Ast String List Nat Int
           UnivSubst Typing Checker Retyping OrderedType Logic Common Equality Classes Number
           Uint63.
Set Warnings "-extraction-opaque-accessed".
Set Warnings "-extraction-reserved-identifier".

From MetaCoq.Erasure Require Import EAst EAstUtils EInduction ELiftSubst ETyping Extract ErasureFunction Erasure.

Extraction Inline Equations.Prop.Classes.noConfusion.
Extraction Inline Equations.Prop.Logic.eq_elim.
Extraction Inline Equations.Prop.Logic.eq_elim_r.
Extraction Inline Equations.Prop.Logic.transport.
Extraction Inline Equations.Prop.Logic.transport_r.
Extraction Inline Equations.Prop.Logic.False_rect_dep.
Extraction Inline Equations.Prop.Logic.True_rect_dep.
Extraction Inline Equations.Init.pr1.
Extraction Inline Equations.Init.pr2.
Extraction Inline Equations.Init.hidebody.
Extraction Inline Equations.Prop.DepElim.solution_left.

Extract Inductive Equations.Init.sigma => "( * )" ["(,)"].
Extract Constant Equations.Init.pr1 => "fst".
Extract Constant Equations.Init.pr2 => "snd".
Extraction Inline Equations.Init.pr1 Equations.Init.pr2.

Extract Constant PCUICTyping.guard_checking => "{ fix_guard = (fun _ _ _ -> true); cofix_guard = (fun _ _ _ -> true) }".

Cd "src".

Separate Extraction ErasureFunction.erase Erasure
         (* The following directives ensure separate extraction does not produce name clashes *)
         Coq.Strings.String utils Template.UnivSubst ELiftSubst ETyping.

Cd "..".
