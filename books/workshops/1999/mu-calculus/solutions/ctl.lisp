(in-package "MODEL-CHECK")
(include-book "semantics")

(defabbrev u-formulap (f ap)
  (and (equal (len f) 3)
       (ctl-formulap (first f) ap)
       (ctl-formulap (third f) ap)
       (equal 'u (second f))))

(defun ctl-formulap (f ap)
"True iff f is a ctl formula given that ap is the list of atomic
proposition constants.  Formats of formulas are: p, (f1 & f2), (f1 +
f2), (~ f), (EX f), (AX f), (EF f), (AF f), (EG f), (AG f), (E f U g),
(A f U g), (E ~(f U g)), and (E ~(f U g))"
  (declare (xargs :guard (true-listp ap)))
  (cond ((symbolp f)
	 (or (in f '(true false))
	     (and (mu-symbolp f)
		  (in f ap))))
	((equal (len f) 2)
	 (and (in (first f) '(~ EX AX EF AF EG AG))
	      (ctl-formulap (second f) ap)))
	((equal (len f) 3)
	 (let ((first (first f))
	       (second (second f))
	       (third (third f)))
	   (or (and (in second '(& +))
		    (ctl-formulap first ap)
		    (ctl-formulap third ap))
	       (and (in first '(E A))
		    (equal second '~)
		    (u-formulap third ap)))))
	((equal (len f) 4)
	 (and (in (first f) '(A E))
	      (u-formulap (cdr f) ap)))))

(defabbrev u-formula-no-ap-p (f)
  (and (equal (len f) 3)
       (ctl-formula-no-ap-p (first f))
       (ctl-formula-no-ap-p (third f))
       (equal 'u (second f))))

(defun ctl-formula-no-ap-p (f)
"True iff f is a ctl formula. Formats of formulas are: p, (f1 & f2),
 (f1 + f2), (~ f), (EX f), (AX f), (EF f), (AF f), (EG f), (AG f), (E f
U g), (A f U g), (E ~(f U g)), and (E ~(f U g))"
  (declare (xargs :guard t))
  (cond ((symbolp f)
	 t)
	((equal (len f) 2)
	 (and (in (first f) '(~ EX AX EF AF EG AG))
	      (ctl-formula-no-ap-p (second f))))
	((equal (len f) 3)
	 (let ((first (first f))
	       (second (second f))
	       (third (third f)))
	   (or (and (in second '(& +))
		    (ctl-formula-no-ap-p first)
		    (ctl-formula-no-ap-p third))
	       (and (in first '(E A))
		    (equal second '~)
		    (u-formula-no-ap-p third)))))
	((equal (len f) 4)
	 (and (in (first f) '(A E))
	      (u-formula-no-ap-p (cdr f))))))

; Exercise 25
(defun ctl-2-muc (f)
  (declare (xargs :guard t))
  (cond ((symbolp f)
	 f)
	((equal (len f) 2)
	 (let ((first (first f))
	       (second (second f)))
	   (cond ((in first '(~ EX AX))
		  (list first (ctl-2-muc second)))
		 ((equal first 'EF)
		  `(mu y (,(ctl-2-muc second) + (EX y))))
		 ((equal first 'EG)
		  `(nu y (,(ctl-2-muc second) & (EX y))))
		 ((equal first 'AF)
		  `(mu y (,(ctl-2-muc second) + (AX y))))
		 ((equal first 'AG)
		  `(nu y (,(ctl-2-muc second) & (AX y)))))))
	((equal (len f) 3)
	 (let ((first (first f))
	       (second (second f))
	       (third (third f)))
	   (cond ((in second '(& +))
		  (list (ctl-2-muc first) second (ctl-2-muc third)))
		 ((equal first 'E)
		 ; translate (E ~ (f U g)), i.e., ~(A f U g)
		  (list '~ (ctl-2-muc (cons 'A (caddr f)))))
		 ; translate (A ~ (f U g)), i.e., ~(E f U g)
		 (t (list '~ (ctl-2-muc (cons 'E (caddr f))))))))
	((equal (len f) 4)
	 (let ((second (second f))
	       (fourth (fourth f)))
	   (cond ((equal (first f) 'E) ; translate (E f U g)
		  `(mu y (,(ctl-2-muc fourth) + (,(ctl-2-muc second)  & (EX y)))))
		 (t ; translate (A f U g)
		  `(mu y (,(ctl-2-muc fourth)  + (,(ctl-2-muc second) & (AX y))))))))))

