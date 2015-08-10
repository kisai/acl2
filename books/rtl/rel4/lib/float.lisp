(in-package "ACL2")

(set-enforce-redundancy t)

(local (include-book "../support/merge"))
(local (include-book "../support/guards"))

(include-book "bits")

(set-inhibit-warnings "theory") ; avoid warning in the next event
(local (in-theory nil))

;;;**********************************************************************
;;;                       SGN, SIG, and EXPO
;;;**********************************************************************

(defund expo (x)
  (declare (xargs :guard t
                  :measure (:? x)))
  (cond ((or (not (rationalp x)) (equal x 0)) 0)
	((< x 0) (expo (- x)))
	((< x 1) (1- (expo (* 2 x))))
	((< x 2) 0)
	(t (1+ (expo (/ x 2))))))

(defund sgn (x)
  (declare (xargs :guard t))
  (if (or (not (rationalp x)) (equal x 0))
      0
    (if (< x 0) -1 +1)))

(defund sig (x)
  (declare (xargs :guard t))
  (if (rationalp x)
      (if (< x 0)
          (- (* x (expt 2 (- (expo x)))))
        (* x (expt 2 (- (expo x)))))
    0))

(defthm fp-rep
    (implies (rationalp x)
	     (equal x (* (sgn x) (sig x) (expt 2 (expo x)))))
  :rule-classes ())

(defthm fp-abs
    (implies (rationalp x)
	     (equal (abs x) (* (sig x) (expt 2 (expo x)))))
  :rule-classes ())

(defthm fp-rep-unique
    (implies (and (rationalp x)
		  (not (= x 0))
		  (rationalp m)
		  (<= 1 m)
		  (< m 2)
		  (integerp e)
		  (= (abs x) (* m (expt 2 e))))
	     (and (= m (sig x))
		  (= e (expo x))))
  :rule-classes ())

(defthmd sgn*
    (implies (and (rationalp x) (rationalp y))
	     (= (sgn (* x y)) (* (sgn x) (sgn y)))))

(defthmd expo-minus
  (equal (expo (* -1 x))
         (expo x)))

(defthmd expo-lower-bound
    (implies (and (rationalp x)
		  (not (equal x 0)))
	     (<= (expt 2 (expo x)) (abs x)))
  :rule-classes :linear)

(defthmd expo-upper-bound
    (implies (and (rationalp x))
	     (< (abs x) (expt 2 (1+ (expo x)))))
  :rule-classes :linear)

(defthmd bvecp-expo
    (implies (case-split (natp x))
	     (bvecp x (1+ (expo x)))))

(defthmd expo>=
    (implies (and (<= (expt 2 n) x)
                  (rationalp x)
		  (integerp n)
		  )
	     (<= n (expo x)))
  :rule-classes :linear)

(defthmd expo<=
    (implies (and (< x (* 2 (expt 2 n)))
                  (< 0 x)
                  (rationalp x)
		  (integerp n)
		  )
	     (<= (expo x) n))
  :rule-classes :linear)

(defthm expo-unique
  (implies (and (<= (expt 2 n) (abs x))
                (< (abs x) (expt 2 (1+ n)))
                (rationalp x)
                (integerp n)
                )
           (equal n (expo x)))
  :rule-classes ())

(defthmd expo-monotone
  (implies (and (<= (abs x) (abs y))
                (case-split (rationalp x))
                (case-split (not (equal x 0)))
                (case-split (rationalp y)))
           (<= (expo x) (expo y)))
  :rule-classes :linear)

(defthm expo-2**n
    (implies (integerp n)
	     (equal (expo (expt 2 n))
		    n)))

(defthmd expo-shift
  (implies (and (rationalp x)
                (not (equal x 0))
                (integerp n))
           (equal (expo (* (expt 2 n) x))
                  (+ n (expo x)))))

(defthmd expo-x+2**k
    (implies (and (< (expo x) k)
                  (<= 0 x)
                  (case-split (integerp k))
		  (case-split (rationalp x))
		  )
	     (equal (expo (+ x (expt 2 k)))
		    k)))

(defthmd expo-prod-lower
    (implies (and (rationalp x)
		  (not (= x 0))
		  (rationalp y)
		  (not (= y 0)))
	     (<= (+ (expo x) (expo y)) (expo (* x y))))
  :rule-classes :linear)

(defthmd expo-prod-upper
    (implies (and (rationalp x)
		  (not (= x 0))
		  (rationalp y)
		  (not (= y 0)))
	     (>= (+ (expo x) (expo y) 1) (expo (* x y))))
  :rule-classes :linear)

(defthmd mod-expo
  (implies (and (< 0 x)
                (rationalp x))
           (equal (mod x (expt 2 (expo x)))
                  (- x (expt 2 (expo x))))))

(defthmd sig-minus
  (equal (sig (* -1 x))
         (sig x)))

(defthmd sig-lower-bound
  (implies (and (rationalp x)
                (not (equal x 0)))
           (<= 1 (sig x)))
  :rule-classes (:rewrite :linear))

(defthmd sig-upper-bound
  (< (sig x) 2)
  :rule-classes (:rewrite :linear))

(defthmd sig-shift
  (equal (sig (* (expt 2 n) x))
         (sig x)))

(defthm already-sig
  (implies (and (rationalp x)
                (<= 1 x)
                (< x 2))
           (= (sig x) x)))

(defthm sig-sig
    (equal (sig (sig x))
	   (sig x)))


;;;**********************************************************************
;;;                            EXACTP
;;;**********************************************************************

(defund exactp (x n)
  (integerp (* (sig x) (expt 2 (1- n)))))

(defthmd exactp2
    (implies (and (rationalp x)
		  (integerp n))
	     (equal (exactp x n)
		    (integerp (* x (expt 2 (- (1- n) (expo x))))))))

(defthm exact-neg
    (equal (exactp x n) (exactp (abs x) n))
  :rule-classes ())

(defthm exactp-minus
  (equal (exactp (* -1 x) n)
         (exactp x n)))

(defthmd exactp-shift
  (implies (and (rationalp x)
                (integerp m)
                (integerp n))
           (equal (exactp (* (expt 2 n) x) m)
                  (exactp x m))))

(defthmd exactp-<=
    (implies (and (exactp x m)
                  (<= m n)
                  (rationalp x)
		  (integerp n)
		  (integerp m)
		  )
	     (exactp x n)))

(defthm bvecp-exactp
  (implies (bvecp x n)
           (exactp x n)))

(defthmd exactp-2**n
  (implies  (and (case-split (integerp m))
                 (case-split (> m 0)))
            (exactp (expt 2 n) m)))

(defthm exactp-sig-x
  (equal (exactp (sig x) n)
         (exactp x n)))

(defthm exact-bits-1
  (implies (and (equal (expo x) (1- n))
                (rationalp x)
                (integerp k))
           (equal (integerp (/ x (expt 2 k)))
		  (exactp x (- n k))))
  :rule-classes ())

(defthm exact-bits-2
  (implies (and (equal (expo x) (1- n))
                (rationalp x)
                (<= 0 x)
                (integerp k)
                )
           (equal (integerp (/ x (expt 2 k)))
		  (equal (bits x (1- n) k)
                         (/ x (expt 2 k)))))
  :rule-classes ())

(defthm exact-bits-3
  (implies (integerp x)
           (equal (integerp (/ x (expt 2 k)))
		  (equal (bits x (1- k) 0)
                         0)))
  :rule-classes ())

(defthm exactp-prod
    (implies (and (rationalp x)
		  (rationalp y)
		  (integerp m)
		  (integerp n)
		  (exactp x m)
		  (exactp y n))
	     (exactp (* x y) (+ m n)))
  :rule-classes ())

(defthm exactp-x2
    (implies (and (rationalp x)
		  (integerp k)
		  (exactp x k)
		  (integerp n)
		  (exactp (* x x) (* 2 n)))
	     (exactp x n))
  :rule-classes ())

(defthm exact-k+1
    (implies (and (natp n)
		  (natp x)
		  (= (expo x) (1- n))
		  (natp k)
		  (< k (1- n))
		  (exactp x (- n k)))
	     (iff (exactp x (1- (- n k)))
		  (= (bitn x k) 0)))
  :rule-classes ())

(defun fp+ (x n)
  (+ x (expt 2 (- (1+ (expo x)) n))))

(defthm fp+-positive
  (implies (<= 0 x)
           (< 0 (fp+ x n)))
  :rule-classes :type-prescription)

(defthm fp+1
    (implies (and (rationalp x)
		  (> x 0)
		  (rationalp y)
		  (> y x)
		  (integerp n)
		  (> n 0)
		  (exactp x n)
		  (exactp y n))
	     (>= y (fp+ x n)))
  :rule-classes ())

(defthm fp+2
    (implies (and (rationalp x)
		  (> x 0)
		  (integerp n)
		  (> n 0)
		  (exactp x n))
	     (exactp (fp+ x n) n))
  :rule-classes ())

(defthm exactp-diff
    (implies (and (rationalp x)
		  (rationalp y)
		  (integerp k)
		  (integerp n)
		  (> n 0)
		  (> n k)
		  (exactp x n)
		  (exactp y n)
		  (<= (+ k (expo (- x y))) (expo x))
		  (<= (+ k (expo (- x y))) (expo y)))
	     (exactp (- x y) (- n k)))
  :rule-classes ())

(defthm exactp-diff-0
    (implies (and (rationalp x)
		  (rationalp y)
		  (integerp n)
		  (> n 0)
		  (exactp x n)
		  (exactp y n)
		  (<= (expo (- x y)) (expo x))
		  (<= (expo (- x y)) (expo y)))
	     (exactp (- x y) n))
  :rule-classes ())

(defthm exactp-diff-cor
    (implies (and (rationalp x)
		  (rationalp y)
		  (integerp n)
		  (> n 0)
		  (exactp x n)
		  (exactp y n)
		  (<= (abs (- x y)) (abs x))
		  (<= (abs (- x y)) (abs y)))
	     (exactp (- x y) n))
  :rule-classes ())

(defthm expo-diff-min
    (implies (and (rationalp x)
		  (rationalp y)
		  (> x 0)
		  (> y 0)
		  (integerp n)
		  (> n 0)
		  (exactp x n)
		  (exactp y n)
		  (not (= y x)))
	     (>= (expo (- y x)) (- (1+ (min (expo x) (expo y))) n)))
  :rule-classes ())

(defthm expo-diff-abs-any
    (implies (and (exactp x n)
		  (exactp y n)
                  (rationalp x)
		  (rationalp y)
		  (integerp n)
		  (> n 1)
		  )
	     (<= (abs (expo (- x y)))
		 (+ (max (abs (expo x)) (abs (expo y))) (1- n))))
  :rule-classes ())

