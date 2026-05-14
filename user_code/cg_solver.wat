(module
  ;; Memory: 1 page = 64KiB (keeps linear memory <64KB)
  (memory (export "memory") 1)

  ;; Conjugate Gradient solver for N=4, f32. Exports (solve) which returns
  ;; i32 pointer to solution vector stored at offset 80.
  (func (export "solve") (result i32)
    (local $i i32) (local $j i32) (local $iter i32)
    (local $tmp f32) (local $sum f32) (local $alpha f32) (local $beta f32)
    (local $rr_old f32) (local $rr_new f32) (local $pAp f32)

    ;; Layout (bytes):
    ;; A: offset 0  (4x4 f32 -> 64 bytes)
    ;; b: offset 64 (4 f32 -> 16 bytes)
    ;; x: offset 80 (4 f32)
    ;; r: offset 96 (4 f32)
    ;; p: offset 112 (4 f32)
    ;; Ap: offset 128 (4 f32)

    ;; --- initialize A (row-major) ---
    (f32.store (i32.const 0) (f32.const 4.0))   ;; A[0,0]
    (f32.store (i32.const 4) (f32.const 1.0))   ;; A[0,1]
    (f32.store (i32.const 8) (f32.const 0.0))   ;; A[0,2]
    (f32.store (i32.const 12) (f32.const 0.0))  ;; A[0,3]

    (f32.store (i32.const 16) (f32.const 1.0))  ;; A[1,0]
    (f32.store (i32.const 20) (f32.const 3.0))  ;; A[1,1]
    (f32.store (i32.const 24) (f32.const 1.0))  ;; A[1,2]
    (f32.store (i32.const 28) (f32.const 0.0))  ;; A[1,3]

    (f32.store (i32.const 32) (f32.const 0.0))  ;; A[2,0]
    (f32.store (i32.const 36) (f32.const 1.0))  ;; A[2,1]
    (f32.store (i32.const 40) (f32.const 2.0))  ;; A[2,2]
    (f32.store (i32.const 44) (f32.const 1.0))  ;; A[2,3]

    (f32.store (i32.const 48) (f32.const 0.0))  ;; A[3,0]
    (f32.store (i32.const 52) (f32.const 0.0))  ;; A[3,1]
    (f32.store (i32.const 56) (f32.const 1.0))  ;; A[3,2]
    (f32.store (i32.const 60) (f32.const 2.0))  ;; A[3,3]

    ;; --- initialize b ---
    (f32.store (i32.const 64) (f32.const 1.0))
    (f32.store (i32.const 68) (f32.const 2.0))
    (f32.store (i32.const 72) (f32.const 3.0))
    (f32.store (i32.const 76) (f32.const 4.0))

    ;; x = 0 at offset 80
    (f32.store (i32.const 80) (f32.const 0.0))
    (f32.store (i32.const 84) (f32.const 0.0))
    (f32.store (i32.const 88) (f32.const 0.0))
    (f32.store (i32.const 92) (f32.const 0.0))

    ;; r = b (offset 96)
    (f32.store (i32.const 96) (f32.load (i32.const 64)))
    (f32.store (i32.const 100) (f32.load (i32.const 68)))
    (f32.store (i32.const 104) (f32.load (i32.const 72)))
    (f32.store (i32.const 108) (f32.load (i32.const 76)))

    ;; p = r (offset 112)
    (f32.store (i32.const 112) (f32.load (i32.const 96)))
    (f32.store (i32.const 116) (f32.load (i32.const 100)))
    (f32.store (i32.const 120) (f32.load (i32.const 104)))
    (f32.store (i32.const 124) (f32.load (i32.const 108)))

    ;; rr_old = dot(r,r)
    (local.set $sum (f32.const 0.0))
    (local.set $i (i32.const 0))
    (block $dot_r_exit
      (loop $dot_r_loop
        (br_if $dot_r_exit (i32.ge_u (local.get $i) (i32.const 4)))
        (local.set $tmp
          (f32.mul
            (f32.load (i32.add (i32.const 96) (i32.mul (local.get $i) (i32.const 4))))
            (f32.load (i32.add (i32.const 96) (i32.mul (local.get $i) (i32.const 4))))))
        (local.set $sum (f32.add (local.get $sum) (local.get $tmp)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $dot_r_loop)
      )
    )
    (local.set $rr_old (local.get $sum))

    ;; main iteration loop, max_iter = 16
    (local.set $iter (i32.const 0))
    (block $outer_break
      (loop $outer_loop

        ;; Ap = A * p  (Ap at offset 128)
        (local.set $i (i32.const 0))
        (block $mat_exit
          (loop $mat_loop
            (br_if $mat_exit (i32.ge_u (local.get $i) (i32.const 4)))
            (local.set $sum (f32.const 0.0))
            (local.set $j (i32.const 0))
            (block $row_exit
              (loop $row_loop
                (br_if $row_exit (i32.ge_u (local.get $j) (i32.const 4)))
                ;; load A[i,j] and p[j]
                (local.set $tmp
                  (f32.mul
                    (f32.load (i32.add (i32.mul (local.get $i) (i32.const 16)) (i32.mul (local.get $j) (i32.const 4))))
                    (f32.load (i32.add (i32.const 112) (i32.mul (local.get $j) (i32.const 4))))))
                (local.set $sum (f32.add (local.get $sum) (local.get $tmp)))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))
                (br $row_loop)
              )
            )
            (f32.store (i32.add (i32.const 128) (i32.mul (local.get $i) (i32.const 4))) (local.get $sum))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $mat_loop)
          )
        )

        ;; pAp = dot(p, Ap)
        (local.set $sum (f32.const 0.0))
        (local.set $i (i32.const 0))
        (block $dot_pAp_exit
          (loop $dot_pAp_loop
            (br_if $dot_pAp_exit (i32.ge_u (local.get $i) (i32.const 4)))
            (local.set $tmp
              (f32.mul
                (f32.load (i32.add (i32.const 112) (i32.mul (local.get $i) (i32.const 4))))
                (f32.load (i32.add (i32.const 128) (i32.mul (local.get $i) (i32.const 4))))))
            (local.set $sum (f32.add (local.get $sum) (local.get $tmp)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $dot_pAp_loop)
          )
        )
        (local.set $pAp (local.get $sum))

        ;; if pAp == 0 -> break
        (br_if $outer_break (f32.eq (local.get $pAp) (f32.const 0.0)))

        ;; alpha = rr_old / pAp
        (local.set $alpha (f32.div (local.get $rr_old) (local.get $pAp)))

        ;; x = x + alpha * p
        (local.set $i (i32.const 0))
        (block $x_update_exit
          (loop $x_update_loop
            (br_if $x_update_exit (i32.ge_u (local.get $i) (i32.const 4)))
            (local.set $tmp
              (f32.add
                (f32.load (i32.add (i32.const 80) (i32.mul (local.get $i) (i32.const 4))))
                (f32.mul (local.get $alpha) (f32.load (i32.add (i32.const 112) (i32.mul (local.get $i) (i32.const 4)))))))
            (f32.store (i32.add (i32.const 80) (i32.mul (local.get $i) (i32.const 4))) (local.get $tmp))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $x_update_loop)
          )
        )

        ;; r = r - alpha * Ap
        (local.set $i (i32.const 0))
        (block $r_update_exit
          (loop $r_update_loop
            (br_if $r_update_exit (i32.ge_u (local.get $i) (i32.const 4)))
            (local.set $tmp
              (f32.sub
                (f32.load (i32.add (i32.const 96) (i32.mul (local.get $i) (i32.const 4))))
                (f32.mul (local.get $alpha) (f32.load (i32.add (i32.const 128) (i32.mul (local.get $i) (i32.const 4)))))))
            (f32.store (i32.add (i32.const 96) (i32.mul (local.get $i) (i32.const 4))) (local.get $tmp))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $r_update_loop)
          )
        )

        ;; rr_new = dot(r,r)
        (local.set $sum (f32.const 0.0))
        (local.set $i (i32.const 0))
        (block $dot_rr_exit
          (loop $dot_rr_loop
            (br_if $dot_rr_exit (i32.ge_u (local.get $i) (i32.const 4)))
            (local.set $tmp
              (f32.mul
                (f32.load (i32.add (i32.const 96) (i32.mul (local.get $i) (i32.const 4))))
                (f32.load (i32.add (i32.const 96) (i32.mul (local.get $i) (i32.const 4))))))
            (local.set $sum (f32.add (local.get $sum) (local.get $tmp)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $dot_rr_loop)
          )
        )
        (local.set $rr_new (local.get $sum))

        ;; convergence: ||r||^2 < tol^2
        (br_if $outer_break (f32.lt (local.get $rr_new) (f32.const 1.0e-12)))

        ;; beta = rr_new / rr_old
        (local.set $beta (f32.div (local.get $rr_new) (local.get $rr_old)))

        ;; p = r + beta * p
        (local.set $i (i32.const 0))
        (block $p_update_exit
          (loop $p_update_loop
            (br_if $p_update_exit (i32.ge_u (local.get $i) (i32.const 4)))
            (local.set $tmp
              (f32.add
                (f32.load (i32.add (i32.const 96) (i32.mul (local.get $i) (i32.const 4))))
                (f32.mul (local.get $beta) (f32.load (i32.add (i32.const 112) (i32.mul (local.get $i) (i32.const 4)))))))
            (f32.store (i32.add (i32.const 112) (i32.mul (local.get $i) (i32.const 4))) (local.get $tmp))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $p_update_loop)
          )
        )

        (local.set $rr_old (local.get $rr_new))
        (local.set $iter (i32.add (local.get $iter) (i32.const 1)))
        (br_if $outer_break (i32.ge_s (local.get $iter) (i32.const 16)))
        (br $outer_loop)
      )
    )

    ;; return pointer to x in memory
    (i32.const 80)
  )
)
