;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
; Proving "Uniform Candy Distribution" problem with Z3 SMT-solver
; written by Masahiro Sakai
;
; Usage:
; 
;   > z3 ucd.smt2
;
;   を実行し、出力がunsatと警告のみで、satがないことを確認する。
; 
; 簡単な説明:
;
;   Z3[1,2]等のSMTソルバ[3]は非解釈関数や整数・有理数に関する線形不等式等
;   からなる論理式の解を求めるためのソルバだが、解が存在しないことを確認す
;   ることにより、定理証明にも使うことができる。Pを証明したければ、¬Pに解
;   が存在しないことを示せば良い。これをここでは以下のようにすることで実現
;   している。
;
;     (push)
;       (assert (not P))
;       (check-sat) ; unsat
;     (pop)
;
;   (push) によりコンテキストを保存し、(assert (not P)) によって一時的に
;   ¬Pを制約に追加し、(check-sat) によって制約を満たす解を探索させている。
;   探索の結果、unsatすなわち解が存在せず制約を充足出来ないことが示される。
;   解が存在しないのは制約が矛盾しているためであり、背理法によりPが真である
;   ことが確認できる。その後、(pop)によりコンテキストを復元し、一時的
;   に追加した制約(not P)を取り除いている。
;
;   この手法による定理証明は完全ではないが健全である。具体的には全称量化子
;   を含む場合等には、充足不可能な制約条件であっても、常に充足不可能と判定
;   して終了できるとは限らない。しかし、充足不可能と判定された場合にはそれ
;   は常に正しい判定になっている。
;
;   今、Pが真である(他の制約から含意される)ことが示せたため、Pを制約条件
;   として追加しても論理的には同値である。しかし、上記手法による定理証明は
;   健全ではあるが完全ではないため、Pを明示的に制約条件として追加しないと
;   後の命題が証明できない場合もあり、そのような場合には、(assert P) によっ
;   て明示的にPを制約条件に追加している。
; 
;   上記手法による定理証明が不完全な点の一つは、帰納法を必要とするような命
;   題を証明できないことである。そこで、∀n. P(n) を数学的帰納法によって証
;   明する場合には、P(0) および ∀n. P(n) → P(n+1) をそれぞれ上記方法によっ
;   て証明し、その後 ∀n. P(n) を assert によって明示的に制約として追加する
;   ということを行っている。また、自然数の組の上の辞書式順序による整礎帰納
;   法についても同様にして用いている。
;
;   なお、SMTソルバにて全称量化子や帰納法を取り扱う手法の詳細については、
;   [4,5,6]等を参照されたい。
;
; Latest version:
;
;   Latest version will be available at https://github.com/msakai/tpp2011
; 
; Bibliography:
;
; [1] Z3: An Efficient Theorem Prover
;     http://research.microsoft.com/en-us/um/redmond/projects/z3/
;
; [2] Leonardo de Moura, Nikolaj Bjørne. Z3 - a Tutorial.
;     http://research.microsoft.com/en-us/um/redmond/projects/z3/tutorial.pdf 
; 
; [3] Roberto Sebastiani. Lazy Satisfiability Modulo Theories.
;     Journal on Satisfiability, Boolean Modeling and Computation, Vol.3
;     (2007), pp. 141-224.
;
; [4] K. Rustan M. Leino, Rosemary Monahan.
;     Reasoning about comprehensions with first-order SMT solvers.
;     In SAC '09: Proceedings of the 2009 ACM symposium on Applied Computing
;     (2009), pp. 615-622.
;     http://research.microsoft.com/en-us/um/people/leino/papers/rmkrml183.pdf
;
; [5] Michał Moska. Programming with Triggers.
;     In Proceedings of the 7th International Workshop on Satisfiability
;     Modulo Theories (2009), pp. 20-29.
;     http://research.microsoft.com/en-us/um/people/moskal/pdf/prtrig.pdf
; 
; [6] K. Rustan M. Leino. Automating Induction with an SMT Solver.
;     To appear at VMCAI 2012.
;     http://research.microsoft.com/en-us/um/people/leino/papers/krml218.pdf
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(set-option :print-success false)

(declare-fun N () Int)
(assert (> N 0))

(define-fun is-nat ((n Int)) Bool (>= n 0))
(define-fun is-even ((n Int)) Bool (= (mod n 2) 0))
(define-fun is-even-nat ((n Int)) Bool (and (is-nat n) (is-even n)))
(define-fun is-child ((i Int)) Bool (and (<= 1 i) (<= i N)))

; Let m(i,k) be the number of candies held by the i'th child (i in {1,...,N})
; after k steps. 
(declare-fun m (Int Int) Int)

; Def. max(k) = max{m(i,k) | i in {1,...,N}}
(declare-fun max-child (Int) Int)
(define-fun max2 ((k Int)) Int (m (max-child k) k))
(assert
  (forall ((k Int))
    (! (is-child (max-child k))
       :pattern ((max-child k)))))
(assert
  (forall ((k Int) (i Int))
    (! (=> (is-child i) (>= (max2 k) (m i k)))
       :pattern ((m i k)) )))

; Def. min(k) = min{m(i,k) | i in {1,...,N}}
(declare-fun min-child (Int) Int)
(define-fun min2 ((k Int)) Int (m (min-child k) k))
(assert
  (forall ((k Int))
    (! (is-child (min-child k))
       :pattern ((min-child k)) )))
(assert
  (forall ((k Int) (i Int))
    (! (=> (is-child i) (<= (min2 k) (m i k)))
       :pattern ((m i k)) )))

; Def. right(i) = (if (i < N) then (i+1) else 1).
(define-fun right ((i Int)) Int (ite (< i N) (+ i 1) 1))

; Def. num(n,k) is the number of children holding m candies after k steps.
; Note that the axiomatization is partial/incomplete.
(declare-fun num (Int Int) Int)
(assert
  (forall ((n Int) (k Int))
    (! (is-nat (num n k))
       :pattern ((num n k)))))
(assert
  (forall ((n Int) (k Int))
    (! (=>
         (exists ((i Int)) (and (is-child i) (= (m i k) n) (not (= (m i (+ k 1)) n))))
         (forall ((i Int)) (=> (is-child i) (not (= (m i k) n)) (not (= (m i (+ k 1)) n))))
         (< (num n (+ k 1)) (num n k)))
       :pattern ((num n k)) )))

; initial state
(assert
  (forall ((i Int) (k Int))
    (! (=> (is-child i) (= k 0) (is-even-nat (m i k)))
       :pattern ((m i k)) )))

; transition relation
(define-fun trans ((i Int) (k Int)) Bool
  (let ((tmp (+ (div (m i k) 2) (div (m (right i) k) 2))))
       (= (m i (+ k 1))
          (ite (is-even tmp) tmp (+ tmp 1)))))
; To avoid trigger loop
; 本来はここで制約を追加すべきだが、trigger loop を避けるために、個々のkに対して
; 手動で指定する。
;(assert 
;  (forall ((i Int) (k Int))
;    (=> (is-child i) (is-nat k) (trans i k))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Def. state invariant
(define-fun state-inv ((k Int)) Bool
  (forall ((i Int))
    (! (=> (is-child i) (is-even-nat (m i k)))
       :pattern ((m i k)) )))
; Lemma. Preservation of state invariant
; base case: state-inv(0)
(push)
  (assert (not (state-inv 0))) ; negation of the goal
  (check-sat) ; unsat
(pop)
; induction step: state-inv(k) → state-inv(k+1)
(push)
  (declare-fun k () Int)
  (declare-fun k1 () Int)
  (assert (and (is-nat k) (= (+ k 1) k1)))
  ; 本来前もって追加しておくべきだが、前述の理由からここで追加
  (assert (forall ((i Int)) (! (=> (is-child i) (trans i k)) :pattern ((m i k1)) )))
  (assert (state-inv k)) ; induction hypothesis
  (assert (not (state-inv k1))) ; negation of the goal
  (check-sat) ; unsat
(pop)
; conclusion of induction
; 
; Note:
; - state-inv is not reused since we want to use (m i k) as a trigger.
; - is-nat should not be used as a trigger since it is interpreted function.
(assert
  (forall ((i Int) (k Int))
    (! (=> (is-child i) (is-nat k) (is-even-nat (m i k)))
       :pattern ((m i k)) )))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; loop variant
(define-fun loop-variant-1 ((k Int)) Int (- (max2 k) (min2 k)))
(define-fun loop-variant-2 ((k Int)) Int (num (min2 k) k))

; lexicographical ordering
; define-funで定義するのが自然だが、triggerにしたいのでdeclare-funで定義
(declare-fun lt (Int Int Int Int) Bool)
(assert
  (forall ((a1 Int) (a2 Int) (b1 Int) (b2 Int))
    (= (lt a1 a2 b1 b2)
       (and (is-nat a1) (is-nat a2)
            (or (< a1 b1)
                (and (= a1 b1) (< a2 b2)))))))

(define-fun loop-variant-decrease ((k Int)) Bool
  (lt (loop-variant-1 (+ k 1)) (loop-variant-2 (+ k 1))
      (loop-variant-1 k) (loop-variant-2 k)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Lemma
; Prove that loop variant decrease in lexicographical ordering.

(push)
  ; triggerに使いたいので、k,k1を共にdeclare-funで宣言
  (declare-fun k () Int)
  (declare-fun k1 () Int)
  (assert (and (is-nat k) (= (+ k 1) k1)))
  ; 本来前もって追加しておくべきだが、前述の理由からここで追加
  (assert (forall ((j Int)) (! (=> (is-child j) (trans j k)) :pattern ((m j k1)) )))

  ; (1) max(k+1) <= max(k)
  (push)
    (assert (not (<= (max2 (+ k 1)) (max2 k)))) ; negation of the goal
    (check-sat) ; unsat
  (pop)

  ; (2) min(k) <= min(k+1)
  (push)
    (assert (not (<= (min2 k) (min2 (+ k 1))))) ; negation of the goal
    (check-sat) ; unsat
  (pop)

  ; (3) if min(k) < m(i,k) then min(k) < m(i,k+1)
  (push)
    (declare-fun i () Int)
    (assert (is-child i))
    (assert (< (min2 k) (m i k)))
    (assert (not (< (min2 k) (m i (+ k 1))))) ; negation of the goal
    (check-sat) ; unsat
  (pop)

  ; (4) if m(i,k) < m(right(i),k) then m(i,k) < m(i,k+1)
  (push)
    (declare-fun i () Int)
    (assert (is-child i))
    (assert (< (m i k) (m (right i) k)))
    (assert (not (< (m i k) (m i (+ k 1))))) ; negation of the goal
    (check-sat) ; unsat
  (pop)

  ; (5) if (min(k) < m(i,k)) for some i,
  ;     then num(min(k),k+1) < num(min(k),k),
  (push)
    ; Suppose (min(k) < m(i,k)) for some i.
    (declare-fun i () Int)
    (assert (is-child i))
    (assert (< (min2 k) (m i k)))

    ; Show m(j,k)=min(k) and min(k)<(j,k+1) for some j.
    (push)
      (assert
        (forall ((j Int))
          (! (=> (is-child j) (= (min2 k) (m j k)) (not (< (min2 k) (m j (+ k 1)))))
             :pattern ((m j k)) ))) ; negation of the goal

      (define-fun P ((j Int)) Bool (= (min2 k) (m j k)))
      ; base case: P(min-child(k))
      (push)
        (assert (not (P (min-child k)))) ; negation of the goal
        (check-sat) ; unsat
      (pop)
      ; induction step: P(j) → P(right(j))
      (push)
        (declare-fun j () Int)
        (assert (is-child j))
        (assert (P j)) ; induction hypothesis
        (assert (not (P (right j)))) ; negation of the goal
        (check-sat) ; unsat
      (pop)
      ; conclusion of the induction
      ; (P(j) → (∀l. P(l)→P(right(l))) → ∀l. P(l)) を仮定してしまっているのに注意。
      (assert (forall ((j Int)) (! (=> (is-child j)  (P j)) :pattern ((m j k)) )))

      (check-sat) ; unsat
    (pop)
    (assert
      (exists ((j Int))
        (and (is-child j)
             (= (min2 k) (m j k))
             (< (min2 k) (m j (+ k 1))))))

    ; Show that (num(min(k), k+1) < num(min(k), k)) holds.
    (push)
      (assert (not (< (num (min2 k) (+ k 1)) (num (min2 k) k)))) ; negation of the goal
      (check-sat) ; unsat
    (pop)

    ; Show that loop variant decrease in lexicographical ordering.
    (push)
      (assert (not (loop-variant-decrease k))) ; negation of the goal
      (check-sat) ; unsat
    (pop)
  (pop)

(pop)

(assert
  (forall ((k Int))
    (! (=> (is-nat k)
           (exists ((i Int)) (! (< (min2 k) (m i k)) :pattern ((m i k))))
           (loop-variant-decrease k))
       :pattern ((min2 k)) )))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; define-funで定義するのが自然だが、triggerにしたいのでdeclare-funで定義
(declare-fun P (Int Int) Bool)
(assert
  (forall ((lv1 Int) (lv2 Int))
    (! (= (P lv1 lv2)
          (forall ((k Int))
            (! (=> (is-nat k)
                   (= lv1 (loop-variant-1 k))
                   (= lv2 (loop-variant-2 k))
                   (exists ((k1 Int))
       	          (! (and (is-nat k1) (= (min2 k1) (max2 k1)))
                        :pattern ((min2 k1)))))
               :pattern ((min2 k)))))
       :pattern ((P lv1 lv2)))))

; Lemma
; Prove (∀v1,v2. P(v1,v2)) using well-founded induction on lt.
(push)
  (declare-fun v1 () Int)
  (declare-fun v2 () Int)
  (assert (is-nat v1))
  (assert (is-nat v2))

  ; induction hypothesis
  (assert 
    (forall ((u1 Int) (u2 Int))
      (! (=> (lt u1 u2 v1 v2) (P u1 u2))
         :pattern ((lt u1 u2 v1 v2)))))

  ; negation of the goal
  (assert (not (P v1 v2)))

  (check-sat) ; unsat
(pop)
(assert (forall ((v1 Int) (v2 Int)) (P v1 v2)))

; Lemma
(push)
  (assert (not (P (loop-variant-1 0) (loop-variant-2 0))))
  (check-sat) ; unsat
(pop)
(assert (P (loop-variant-1 0) (loop-variant-2 0)))

; Theorem: ∃k. min(k)=max(k)
(push)
  (assert (not (exists ((k1 Int)) (and (is-nat k1) (= (min2 k1) (max2 k1))))))
  (check-sat) ; unsat
(pop)
; QED

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Proof outline:
; Let m(i,k) be the number of candies held by the i'th
; child (i in {1,...,N}) after k steps. At first, prove the following
; lemmas:
; 
;  (1) max(k+1) <= max(k),
;  (2) min(k) <= min(k+1),
;  (3) if min(k) < m(i,k) then min(k) < m(i,k+1),
;  (4) if m(i,k) < m(right(i),k) then m(i,k) < m(i,k+1),
; 
; where
; 
;     max(k) = max{m(i,k) | i in {1,...,N}},
;     min(k) = min{m(i,k) | i in {1,...,N}},
;   right(i) = (if (i < N) then (i+1) else 1).
; 
; Then, prove the following lemma:
; 
;  (5) if (min(k) < m(i,k)) for some i,
;      then num(min(k),k+1) < num(min(k),k),
; 
; where
; 
;   num(m,k) is the number of children holding m candies after k steps.
; 
; Finally, it can be proven that all the children eventually hold the
; same number of candies.
