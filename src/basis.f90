#include "config.h"
!
!        basis.f90
!        new_quick
!
!        Created by Yipu Miao on 3/9/11.
!        Copyright 2011 University of Florida. All rights reserved.
!

subroutine readbasis(natomxiao, natomstart, natomfinal, nbasisstart, nbasisfinal)
   !
   ! Read in the requested basisfile. This is done twice, once to get sizes and
   ! allocate variables, then again to assign the basis
   !
   use allmod
   !
   implicit double precision(a - h, o - z)
   character(len=80) :: line
   character(len=2) :: atom, shell
   logical :: isatom
   integer, dimension(0:92)  :: kcontract, kbasis
   logical, dimension(0:92)  :: atmbs, atmbs2

   double precision AA(MAXPRIM), BB(MAXPRIM), CC(MAXPRIM)
   integer natomstart, natomfinal, nbasisstart, nbasisfinal
   double precision, allocatable, save, dimension(:) :: aex, gcs, gcp, gcd, gcf, gcg
#ifdef MPI
   include 'mpif.h'
#endif

   ! =============MPI/ MASTER========================
   masterwork: if (master) then
      ! =============END MPI/MASTER=====================
      ! Alessandro GENONI 03/05/2007
      ! Only for ECP calculations:
      ! * Allocate arrays whose dimensions depend on NATOM (allocateatoms_ecp)
      ! * Read the Effective Core Potentials (ECPs), modify the atomic charges
      !   and the total number of electrons (readecp)
      if (quick_method%ecp) call readecp
      call quick_open(ibasisfile, basisfilename, 'O', 'F', 'W', .true.)
      iofile = 0
      nshell = 0
      nbasis = 0
      nprim = 0
      kcontract = 0
      quick_basis%kshell = 0
      kbasis = 0
      atmbs = .true.
      atmbs2 = .true.
      icont = 0
      quick_method%ffunxiao = .true.

      ! parse the file and find the sizes of things to allocate them in memory
      do while (iofile == 0)
         read (ibasisfile, '(A80)', iostat=iofile) line
         read (line, *, iostat=io) atom, ii
         if (io == 0 .and. ii == 0) then
            isatom = .true.
            do i = 1, 92
               if (symbol(i) == atom) then
                  iat = i
                  atmbs(i) = .false.
                  atmbs2(i) = .false.
                  icont = icont + 1
               end if
            enddo
            iatom = 0
            do while (iatom == 0)
               read (ibasisfile, '(A80)', iostat=iofile) line
               read (line, *, iostat=iatom) shell, iprim, dnorm
               if (iatom == 0) then
                  quick_basis%kshell(iat) = quick_basis%kshell(iat) + 1
                  kcontract(iat) = kcontract(iat) + iprim
                  if (shell == 'S') then
                     kbasis(iat) = kbasis(iat) + 1
                  elseif (shell == 'P') then
                     kbasis(iat) = kbasis(iat) + 3
                  elseif (shell == 'SP') then
                     kbasis(iat) = kbasis(iat) + 4
                  elseif (shell == 'D') then
                     kbasis(iat) = kbasis(iat) + 6
                  elseif (shell == 'F') then
                     quick_method%ffunxiao = .false.
                     kbasis(iat) = kbasis(iat) + 10
                  end if
                  if (shell == 'SP') then
                     do i = 1, iprim
                        read (ibasisfile, '(A80)', iostat=iofile) line
                        read (line, *) a, c1, c2
                     enddo
                  else
                     do i = 1, iprim
                        read (ibasisfile, '(A80)', iostat=iofile) line
                        read (line, *) a, d
                     enddo
                  end if
               end if
            enddo
         end if
      enddo
      rewind ibasisfile

      !
      ! Alessandro GENONI: 03/07/2007
      !
      ! This part of the code is important for the ECP calculations.
      ! It allows to read the basis-set from the CUSTOM File for those
      ! elements (in the studied molecule) that don't have the proper
      ! ECP basis-set! (Not for ECP=CUSTOM)
      !
      if ((quick_method%ecp .and. (icont /= 92)) .and. (.not. quick_method%custecp)) then
         open (ibasiscustfile, file=basiscustname, status='old')
         do jj = 1, natomxiao
            if (atmbs(quick_molspec%iattype(jj))) then
               atmbs(quick_molspec%iattype(jj)) = .false.
               iofile = 0
               do while (iofile == 0)
                  read (ibasiscustfile, '(A80)', iostat=iofile) line
                  read (line, *, iostat=io) atom, ii
                  if (io == 0 .and. ii == 0) then
                     if (symbol(quick_molspec%iattype(jj)) == atom) then
                        iat = quick_molspec%iattype(jj)
                        iatom = 0
                        do while (iatom == 0)
                           read (ibasiscustfile, '(A80)', iostat=iofile) line
                           read (line, *, iostat=iatom) shell, iprim, dnorm
                           if (iatom == 0) then
                              quick_basis%kshell(iat) = quick_basis%kshell(iat) + 1
                              kcontract(iat) = kcontract(iat) + iprim
                              if (shell == 'S') then
                                 kbasis(iat) = kbasis(iat) + 1
                              elseif (shell == 'P') then
                                 kbasis(iat) = kbasis(iat) + 3
                              elseif (shell == 'SP') then
                                 kbasis(iat) = kbasis(iat) + 4
                              elseif (shell == 'D') then
                                 kbasis(iat) = kbasis(iat) + 6
                              elseif (shell == 'F') then
                                 quick_method%ffunxiao = .false.
                                 kbasis(iat) = kbasis(iat) + 10
                              end if
                              if (shell == 'SP') then
                                 do i = 1, iprim
                                    read (ibasiscustfile, '(A80)', iostat=iofile) line
                                    read (line, *) a, c1, c2
                                 enddo
                              else
                                 do i = 1, iprim
                                    read (ibasiscustfile, '(A80)', iostat=iofile) line
                                    read (line, *) a, d
                                 enddo
                              end if
                           end if
                        end do
                     end if
                  end if
               end do
               rewind ibasiscustfile
            end if
         end do
      end if

      !do i=1,83
      !  if (quick_basis%kshell(i) /= 0) print *, symbol(i),quick_basis%kshell(i),kcontract(i),kbasis(i)
      !enddo

      do i = 1, natomxiao

         ! MFCC
         if (i .eq. natomstart) nbasisstart = nbasis + 1
         do ixiao = 1, npmfcc
            if (matomstart(ixiao) .eq. i) then
               matombases(ixiao) = nbasis + 1
               !         print*,ixiao,'matombases(ixiao)=',matomstart(ixiao),matombases(ixiao)
            endif
         enddo

         do ixiao = 1, npmfcc - 1
            if (matomstartcap(ixiao) .eq. i) then
               matombasescap(ixiao) = nbasis + 1
               !         print*,ixiao,'matombases(ixiao)=',matomstart(ixiao),matombases(ixiao)
            endif
         enddo

         do ixiao = 1, kxiaoconnect
            if (matomstartcon(ixiao) .eq. i) then
               matombasescon(ixiao) = nbasis + 1
               matombasesconi(ixiao) = nbasis + 1
               !         print*,ixiao,'matombases(ixiao)=',matomstart(ixiao),matombases(ixiao)
            endif
         enddo

         do ixiao = 1, kxiaoconnect
            if (matomstartcon2(ixiao) .eq. i) then
               matombasescon2(ixiao) = nbasis + 1
               matombasesconj(ixiao) = nbasis + 1
               !         print*,ixiao,'matombases(ixiao)=',matomstart(ixiao),matombases(ixiao)
            endif
         enddo

         ! MFCC

         !   print*,nshell,nbasis,nprim,quick_basis%kshell(iattype(i)),kbasis(iattype(i)),kcontract(iattype(i))
         nshell = nshell + quick_basis%kshell(quick_molspec%iattype(i))
         nbasis = nbasis + kbasis(quick_molspec%iattype(i))
         nprim = nprim + kcontract(quick_molspec%iattype(i))

         ! MFCC
         if (i .eq. natomfinal) nbasisfinal = nbasis
         do ixiao = 1, npmfcc
            if (matomfinal(ixiao) .eq. i) matombasef(ixiao) = nbasis
         enddo

         do ixiao = 1, npmfcc - 1
            if (matomfinalcap(ixiao) .eq. i) matombasefcap(ixiao) = nbasis
         enddo

         do ixiao = 1, kxiaoconnect
            if (matomfinalcon(ixiao) .eq. i) then
               matombasefcon(ixiao) = nbasis
               matombasefconi(ixiao) = nbasis
            endif
         enddo

         do ixiao = 1, kxiaoconnect
            if (matomfinalcon2(ixiao) .eq. i) then
               matombasefcon2(ixiao) = nbasis
               matombasefconj(ixiao) = nbasis
            endif
         enddo

         ! MFCC

      enddo
      ! =============MPI/MASTER=====================
   endif masterwork
   ! =============END MPI/MASTER=====================

#ifdef MPI
   ! =============END MPI/ALL NODES=====================
   if (bMPI) then
      call MPI_BARRIER(MPI_COMM_WORLD, mpierror)
      call MPI_BCAST(natom, 1, mpi_integer, 0, MPI_COMM_WORLD, mpierror)
      call MPI_BCAST(nshell, 1, mpi_integer, 0, MPI_COMM_WORLD, mpierror)
      call MPI_BCAST(nbasis, 1, mpi_integer, 0, MPI_COMM_WORLD, mpierror)
      call MPI_BCAST(nprim, 1, mpi_integer, 0, MPI_COMM_WORLD, mpierror)
      call MPI_BCAST(quick_method%ffunxiao, 1, mpi_logical, 0, MPI_COMM_WORLD, mpierror)
      call MPI_BARRIER(MPI_COMM_WORLD, mpierror)
   endif
#endif

   ! =============END MPI/ALL NODES=====================

   ! Allocate the arrays now that we know the sizes

   if (quick_method%ffunxiao) then
      allocate (Yxiao(4096, 56, 56))
      allocate (Yxiaotemp(56, 56, 0:10))
      allocate (Yxiaoprim(MAXPRIM, MAXPRIM, 56, 56))
      allocate (attraxiao(56, 56, 0:6))
      allocate (attraxiaoopt(3, 56, 56, 0:5))
   else
      allocate (Yxiao(4096, 120, 120))
      allocate (Yxiaotemp(120, 120, 0:14))
      allocate (Yxiaoprim(MAXPRIM, MAXPRIM, 120, 120))
      allocate (attraxiao(120, 120, 0:8))
      allocate (attraxiaoopt(3, 120, 120, 0:7))
   endif

   ! allocate(Yxiao(1296,35,35))
   ! allocate(Yxiaotemp(35,35,0:8))
   ! allocate(Yxiaoprim(6,6,35,35))
   !  allocate(Yxiao(81,10,10))
   !  allocate(Yxiaotemp(10,10,0:4))
   allocate (Ycutoff(nshell, nshell))
   allocate (cutmatrix(nshell, nshell))
!   allocate(allerror(quick_method%maxdiisscf,nbasis,nbasis))
!   allocate(alloperator(quick_method%maxdiisscf,nbasis,nbasis))
   !  allocate(debug1(nbasis,nbasis))
   !  allocate(debug2(nbasis,nbasis))
   ! allocate(CPMEM(10,10,0:4))
   ! allocate(MEM(10,10,0:4))
!   allocate(kstart(nshell))
!   allocate(quick_basis%katom(nshell))
!   allocate(ktype(nshell))
!   allocate(kprim(nshell))
!   allocate(Qnumber(nshell))
!   allocate(Qstart(nshell))
!   allocate(quick_basis%Qfinal(nshell))
!   allocate(Qsbasis(nshell,0:3))
!   allocate(Qfbasis(nshell,0:3))
!   allocate(quick_basis%ksumtype(nshell+1))
!   allocate(KLMN(3,nbasis))
!   allocate(cons(nbasis))
!   allocate(gccoeff(6,nbasis))
!   allocate(gcexpo(6,nbasis))
!   allocate(gcexpomin(nshell))

   allocate (aex(nprim))
   allocate (gcs(nprim))
   allocate (gcp(nprim))
   allocate (gcd(nprim))
   allocate (gcf(nprim))
   allocate (gcg(nprim))

   if (quick_method%ecp) then
      nbf12 = nbasis*(nbasis + 1)/2
      allocate (kmin(nshell))
      allocate (kmax(nshell))
      allocate (eta(nprim))
      allocate (ecp_int(nbf12))
      allocate (kvett(nbf12))
      allocate (gout(25*25))
      allocate (ktypecp(nshell))
      !
      allocate (zlm(lmxdim))
      allocate (flmtx(len_fac, 3))
      allocate (lf(lfdim))
      allocate (lmf(lmfdim))
      allocate (lml(lmfdim))
      allocate (lmx(lmxdim))
      allocate (lmy(lmxdim))
      allocate (lmz(lmxdim))
      allocate (mc(mc1dim, 3))
      allocate (mr(mc1dim, 3))
      allocate (dfac(len_dfac))
      allocate (dfaci(len_dfac))
      allocate (factorial(len_fac))
      allocate (fprod(lfdim, lfdim))
      !
      call vett
   end if

   !
   ! Support for old memory model, to be deleted eventually

   !allocate(aexp(maxcontract,nbasis))
   !allocate(dcoeff(maxcontract,nbasis))
   !allocate(gauss(nbasis))
   !do i=1,nbasis
   !    allocate(gauss(i)%aexp(maxcontract))
   !    allocate(gauss(i)%dcoeff(maxcontract))
   !enddo
   allocate (itype(3, nbasis))
!   allocate(quick_basis%ncenter(nbasis))
   allocate (ncontract(nbasis))

   call alloc(quick_basis, natom, nshell, nbasis)

   do ixiao = 1, nshell
      quick_basis%gcexpomin(ixiao) = 99999.0d0
   enddo
   itype = 0
   quick_basis%ncenter = 0
   ncontract = 0

   ! various arrays that depend on the # of basis functions

   call allocate_quick_gridpoints(nbasis)
!   allocate(V2(3,nbasis))

   ! xiao He may reconsider this
   call alloc(quick_scratch, nbasis)

   ! do this the stupid way for now
   jbasis = 1
   jshell = 1
   Ninitial = 0
   do i = 1, nbasis
      do j = 1, 3
         quick_basis%KLMN(j, i) = 0
      enddo
   enddo

   do i = 1, nshell
      do j = 0, 3
         quick_basis%Qsbasis(i, j) = 0
         quick_basis%Qfbasis(i, j) = 0
      enddo
   enddo

   !====== MPI/MASTER ====================
   masterwork_readfile: if (master) then
      !====== END MPI/MASTER ================

      do i = 1, natomxiao
         if (.not. atmbs2(quick_molspec%iattype(i))) then
            iofile = 0
            do while (iofile == 0)
               read (ibasisfile, '(A80)', iostat=iofile) line
               read (line, *, iostat=io) atom, ii
               if (io == 0 .and. ii == 0) then
                  if (symbol(quick_molspec%iattype(i)) == atom) then
                     iatom = 0
                     do while (iatom == 0)
                        read (ibasisfile, '(A80)', iostat=iofile) line
                        read (line, *, iostat=iatom) shell, iprim, dnorm
                        if (jshell .le. nshell) then
                           quick_basis%kprim(jshell) = iprim
                        endif
                        if (shell == 'S') then
                           quick_basis%ktype(jshell) = 1
                           quick_basis%katom(jshell) = i
                           quick_basis%kstart(jshell) = jbasis
                           quick_basis%Qnumber(jshell) = 0
                           quick_basis%Qstart(jshell) = 0
                           quick_basis%Qfinal(jshell) = 0
                           quick_basis%Qsbasis(jshell, 0) = 0
                           quick_basis%Qfbasis(jshell, 0) = 0
                           quick_basis%ksumtype(jshell) = Ninitial + 1
                           Ninitial = Ninitial + 1
                           quick_basis%cons(Ninitial) = 1.0d0
                           if (quick_method%ecp) then
                              kmin(jshell) = 1
                              kmax(jshell) = 1
                              ktypecp(jshell) = 1
                           end if
                           do k = 1, iprim
                              read (ibasisfile, '(A80)', iostat=iofile) line
                              read (line, *) AA(k), BB(k)
                              aex(jbasis) = AA(k)
                              gcs(jbasis) = BB(k)
                              jbasis = jbasis + 1
                              quick_basis%gccoeff(k, Ninitial) = BB(k)*xnorm(AA(k), 0, 0, 0)
                              quick_basis%gcexpo(k, Ninitial) = AA(k)
                              if (quick_basis%gcexpomin(jshell) .gt. AA(k)) quick_basis%gcexpomin(jshell) = AA(k)
                           enddo
                  xnewtemp = xnewnorm(0, 0, 0, iprim, quick_basis%gccoeff(1:iprim, Ninitial), quick_basis%gcexpo(1:iprim, Ninitial))
                           do k = 1, iprim
                              quick_basis%gccoeff(k, Ninitial) = xnewtemp*quick_basis%gccoeff(k, Ninitial)
                           enddo
                           jshell = jshell + 1
                        elseif (shell == 'P') then
                           quick_basis%ktype(jshell) = 3
                           quick_basis%katom(jshell) = i
                           quick_basis%kstart(jshell) = jbasis
                           quick_basis%Qnumber(jshell) = 6
                           quick_basis%Qstart(jshell) = 1
                           quick_basis%Qfinal(jshell) = 1
                           quick_basis%Qsbasis(jshell, 1) = 0
                           quick_basis%Qfbasis(jshell, 1) = 2
                           quick_basis%ksumtype(jshell) = Ninitial + 1
                           do k = 1, iprim
                              read (ibasisfile, '(A80)', iostat=iofile) line
                              read (line, *) AA(k), BB(k)
                              aex(jbasis) = AA(k)
                              gcp(jbasis) = BB(k)
                              jbasis = jbasis + 1
                           enddo
                           if (quick_method%ecp) then
                              kmin(jshell) = 2
                              kmax(jshell) = 4
                              ktypecp(jshell) = 2
                           end if
                           do jjj = 1, 3
                              Ninitial = Ninitial + 1
                              quick_basis%cons(Ninitial) = 1.0d0
                              quick_basis%KLMN(JJJ, Ninitial) = 1
                              do k = 1, iprim
                                 quick_basis%gccoeff(k, Ninitial) = BB(k)*xnorm(AA(k), 1, 0, 0)
                                 quick_basis%gcexpo(k, Ninitial) = AA(k)
                                 if (quick_basis%gcexpomin(jshell) .gt. AA(k)) quick_basis%gcexpomin(jshell) = AA(k)
                              enddo
                           enddo
                           xnewtemp = xnewnorm(1, 0, 0, iprim, quick_basis%gccoeff(:, Ninitial), quick_basis%gcexpo(:, Ninitial))
                           do iitemp = Ninitial - 2, Ninitial
                              do k = 1, iprim
                                 quick_basis%gccoeff(k, iitemp) = xnewtemp*quick_basis%gccoeff(k, iitemp)
                              enddo
                           enddo

                           jshell = jshell + 1
                        elseif (shell == 'SP') then
                           quick_basis%ktype(jshell) = 4
                           quick_basis%katom(jshell) = i
                           quick_basis%kstart(jshell) = jbasis
                           quick_basis%Qnumber(jshell) = 1
                           quick_basis%Qstart(jshell) = 0
                           quick_basis%Qfinal(jshell) = 1
                           quick_basis%Qsbasis(jshell, 0) = 0
                           quick_basis%Qfbasis(jshell, 0) = 0
                           quick_basis%Qsbasis(jshell, 1) = 1
                           quick_basis%Qfbasis(jshell, 1) = 3

                           quick_basis%ksumtype(jshell) = Ninitial + 1
                           !                 do jjj=1,3
                           !                   Ninitial=Ninitial+1
                           !                   quick_basis%cons(Ninitial)=1.0d0
                           !                   quick_basis%KLMN(JJJ,Ninitial)=1
                           !                 enddo
                           do k = 1, iprim
                              read (ibasisfile, '(A80)', iostat=iofile) line
                              !                 read(line,*) aex(jbasis),gcs(jbasis),gcp(jbasis)
                              read (line, *) AA(k), BB(k), CC(k)
                              aex(jbasis) = AA(k)
                              gcs(jbasis) = BB(k)
                              gcp(jbasis) = CC(k)
                              jbasis = jbasis + 1
                           enddo
                           Ninitial = Ninitial + 1
                           quick_basis%cons(Ninitial) = 1.0d0
                           do k = 1, iprim
                              quick_basis%gccoeff(k, Ninitial) = BB(k)*xnorm(AA(k), 0, 0, 0)
                              quick_basis%gcexpo(k, Ninitial) = AA(k)
                              if (quick_basis%gcexpomin(jshell) .gt. AA(k)) quick_basis%gcexpomin(jshell) = AA(k)
                           enddo
                  xnewtemp = xnewnorm(0, 0, 0, iprim, quick_basis%gccoeff(1:iprim, Ninitial), quick_basis%gcexpo(1:iprim, Ninitial))
                           do k = 1, iprim
                              quick_basis%gccoeff(k, Ninitial) = xnewtemp*quick_basis%gccoeff(k, Ninitial)
                           enddo

                           do jjj = 1, 3
                              Ninitial = Ninitial + 1
                              quick_basis%cons(Ninitial) = 1.0d0
                              quick_basis%KLMN(JJJ, Ninitial) = 1
                              do k = 1, iprim
                                 quick_basis%gccoeff(k, Ninitial) = CC(k)*xnorm(AA(k), 1, 0, 0)
                                 quick_basis%gcexpo(k, Ninitial) = AA(k)
                                 if (quick_basis%gcexpomin(jshell) .gt. AA(k)) quick_basis%gcexpomin(jshell) = AA(k)
                              enddo
                           enddo
                  xnewtemp = xnewnorm(1, 0, 0, iprim, quick_basis%gccoeff(1:iprim, Ninitial), quick_basis%gcexpo(1:iprim, Ninitial))
                           do iitemp = Ninitial - 2, Ninitial
                              do k = 1, iprim
                                 quick_basis%gccoeff(k, iitemp) = xnewtemp*quick_basis%gccoeff(k, iitemp)
                              enddo
                           enddo

                           jshell = jshell + 1
                        elseif (shell == 'D') then
                           quick_basis%ktype(jshell) = 6
                           quick_basis%katom(jshell) = i
                           quick_basis%kstart(jshell) = jbasis
                           quick_basis%Qnumber(jshell) = 2
                           quick_basis%Qstart(jshell) = 2
                           quick_basis%Qfinal(jshell) = 2
                           quick_basis%Qsbasis(jshell, 2) = 0
                           quick_basis%Qfbasis(jshell, 2) = 5

                           quick_basis%ksumtype(jshell) = Ninitial + 1
                           do k = 1, iprim
                              read (ibasisfile, '(A80)', iostat=iofile) line
                              !                   read(line,*) aex(jbasis),gcd(jbasis)
                              read (line, *) AA(k), BB(k)
                              aex(jbasis) = AA(k)
                              gcd(jbasis) = BB(k)
                              jbasis = jbasis + 1
                           enddo
                           do JJJ = 1, 6
                              Ninitial = Ninitial + 1
                              if (JJJ .EQ. 1) then
                                 quick_basis%KLMN(1, Ninitial) = 2
                                 quick_basis%cons(Ninitial) = 1.0D0
                              elseif (JJJ .EQ. 2) then
                                 quick_basis%KLMN(1, Ninitial) = 1
                                 quick_basis%KLMN(2, Ninitial) = 1
                                 quick_basis%cons(Ninitial) = dsqrt(3.0d0)
                              elseif (JJJ .EQ. 3) then
                                 quick_basis%KLMN(2, Ninitial) = 2
                                 quick_basis%cons(Ninitial) = 1.0D0
                              elseif (JJJ .EQ. 4) then
                                 quick_basis%KLMN(1, Ninitial) = 1
                                 quick_basis%KLMN(3, Ninitial) = 1
                                 quick_basis%cons(Ninitial) = dsqrt(3.0d0)
                              elseif (JJJ .EQ. 5) then
                                 quick_basis%KLMN(2, Ninitial) = 1
                                 quick_basis%KLMN(3, Ninitial) = 1
                                 quick_basis%cons(Ninitial) = dsqrt(3.0d0)
                              elseif (JJJ .EQ. 6) then
                                 quick_basis%KLMN(3, Ninitial) = 2
                                 quick_basis%cons(Ninitial) = 1.0d0
                              endif

                              do k = 1, iprim
                                 quick_basis%gccoeff(k, Ninitial) = BB(k)*xnorm(AA(k), quick_basis%KLMN(1, Ninitial), &
                                                                       quick_basis%KLMN(2, Ninitial), quick_basis%KLMN(3, Ninitial))
                                 quick_basis%gcexpo(k, Ninitial) = AA(k)
                                 if (quick_basis%gcexpomin(jshell) .gt. AA(k)) quick_basis%gcexpomin(jshell) = AA(k)
                              enddo
                           enddo
                           if (quick_method%ecp) then
                              kmin(jshell) = 5
                              kmax(jshell) = 10
                              ktypecp(jshell) = 3
                           end if
                      xnewtemp = xnewnorm(2, 0, 0, iprim, quick_basis%gccoeff(:, Ninitial - 3), quick_basis%gcexpo(:, Ninitial - 3))
                           do iitemp = Ninitial - 5, Ninitial - 3
                              do k = 1, iprim
                                 quick_basis%gccoeff(k, iitemp) = xnewtemp*quick_basis%gccoeff(k, iitemp)
                              enddo
                           enddo
                           xnewtemp = xnewnorm(1, 1, 0, iprim, quick_basis%gccoeff(:, Ninitial), quick_basis%gcexpo(:, Ninitial))
                           do iitemp = Ninitial - 2, Ninitial
                              do k = 1, iprim
                                 quick_basis%gccoeff(k, iitemp) = xnewtemp*quick_basis%gccoeff(k, iitemp)
                              enddo
                           enddo

                           jshell = jshell + 1
                        elseif (shell == 'F') then
                           quick_basis%ktype(jshell) = 10
                           quick_basis%katom(jshell) = i
                           quick_basis%kstart(jshell) = jbasis
                           quick_basis%Qnumber(jshell) = 3
                           quick_basis%Qstart(jshell) = 3
                           quick_basis%Qfinal(jshell) = 3
                           quick_basis%Qsbasis(jshell, 3) = 0
                           quick_basis%Qfbasis(jshell, 3) = 9

                           quick_basis%ksumtype(jshell) = Ninitial + 1
                           do k = 1, iprim
                              read (ibasisfile, '(A80)', iostat=iofile) line
                              !                   read(line,*) aex(jbasis),gcf(jbasis)
                              read (line, *) AA(k), BB(k)
                              aex(jbasis) = AA(k)
                              gcf(jbasis) = BB(k)
                              jbasis = jbasis + 1
                           enddo
                           do JJJ = 1, 10
                              Ninitial = Ninitial + 1
                              if (JJJ .EQ. 1) then
                                 quick_basis%KLMN(1, Ninitial) = 3
                                 quick_basis%cons(Ninitial) = 1.0D0
                              elseif (JJJ .EQ. 2) then
                                 quick_basis%KLMN(1, Ninitial) = 2
                                 quick_basis%KLMN(2, Ninitial) = 1
                                 quick_basis%cons(Ninitial) = dsqrt(5.0d0)
                              elseif (JJJ .EQ. 3) then
                                 quick_basis%KLMN(1, Ninitial) = 1
                                 quick_basis%KLMN(2, Ninitial) = 2
                                 quick_basis%cons(Ninitial) = dsqrt(5.0d0)
                              elseif (JJJ .EQ. 4) then
                                 quick_basis%KLMN(2, Ninitial) = 3
                                 quick_basis%cons(Ninitial) = 1.0d0
                              elseif (JJJ .EQ. 5) then
                                 quick_basis%KLMN(1, Ninitial) = 2
                                 quick_basis%KLMN(3, Ninitial) = 1
                                 quick_basis%cons(Ninitial) = dsqrt(5.0d0)
                              elseif (JJJ .EQ. 6) then
                                 quick_basis%KLMN(1, Ninitial) = 1
                                 quick_basis%KLMN(2, Ninitial) = 1
                                 quick_basis%KLMN(3, Ninitial) = 1
                                 quick_basis%cons(Ninitial) = dsqrt(5.0d0)*dsqrt(3.0d0)
                              elseif (JJJ .EQ. 7) then
                                 quick_basis%KLMN(2, Ninitial) = 2
                                 quick_basis%KLMN(3, Ninitial) = 1
                                 quick_basis%cons(Ninitial) = dsqrt(5.0d0)
                              elseif (JJJ .EQ. 8) then
                                 quick_basis%KLMN(1, Ninitial) = 1
                                 quick_basis%KLMN(3, Ninitial) = 2
                                 quick_basis%cons(Ninitial) = dsqrt(5.0d0)
                              elseif (JJJ .EQ. 9) then
                                 quick_basis%KLMN(2, Ninitial) = 1
                                 quick_basis%KLMN(3, Ninitial) = 2
                                 quick_basis%cons(Ninitial) = dsqrt(5.0d0)
                              elseif (JJJ .EQ. 10) then
                                 quick_basis%KLMN(3, Ninitial) = 3
                                 quick_basis%cons(Ninitial) = 1.0d0
                              endif
                              do k = 1, iprim
                                 quick_basis%gccoeff(k, Ninitial) = BB(k)*xnorm(AA(k), quick_basis%KLMN(1, Ninitial), &
                                                                       quick_basis%KLMN(2, Ninitial), quick_basis%KLMN(3, Ninitial))
                                 quick_basis%gcexpo(k, Ninitial) = AA(k)
                                 if (quick_basis%gcexpomin(jshell) .gt. AA(k)) quick_basis%gcexpomin(jshell) = AA(k)
                              enddo
                           enddo

                           if (quick_method%ecp) then
                              kmin(jshell) = 11
                              kmax(jshell) = 20
                              ktypecp(jshell) = 4
                           end if

                           jshell = jshell + 1
                        endif
                     enddo
                  endif
               endif
            enddo
            rewind ibasisfile
         end if

         if (atmbs2(quick_molspec%iattype(i)) .and. quick_method%ecp) then
            iofile = 0
            do while (iofile == 0)
               read (ibasiscustfile, '(A80)', iostat=iofile) line
               read (line, *, iostat=io) atom, ii
               if (io == 0 .and. ii == 0) then
                  if (symbol(quick_molspec%iattype(i)) == atom) then
                     iatom = 0
                     do while (iatom == 0)
                        read (ibasiscustfile, '(A80)', iostat=iofile) line
                        read (line, *, iostat=iatom) shell, iprim, dnorm
                        quick_basis%kprim(jshell) = iprim
                        if (shell == 'S') then
                           quick_basis%ktype(jshell) = 1
                           quick_basis%katom(jshell) = i
                           quick_basis%kstart(jshell) = jbasis
                           kmin(jshell) = 1
                           kmax(jshell) = 1
                           ktypecp(jshell) = 1
                           do k = 1, iprim
                              read (ibasiscustfile, '(A80)', iostat=iofile) line
                              read (line, *) aex(jbasis), gcs(jbasis)
                              jbasis = jbasis + 1
                           enddo
                           jshell = jshell + 1
                        elseif (shell == 'P') then
                           quick_basis%ktype(jshell) = 3
                           quick_basis%katom(jshell) = i
                           quick_basis%kstart(jshell) = jbasis
                           kmin(jshell) = 2
                           kmax(jshell) = 4
                           ktypecp(jshell) = 2
                           do k = 1, iprim
                              read (ibasiscustfile, '(A80)', iostat=iofile) line
                              read (line, *) aex(jbasis), gcp(jbasis)
                              jbasis = jbasis + 1
                           enddo
                           jshell = jshell + 1
                        elseif (shell == 'D') then
                           quick_basis%ktype(jshell) = 6
                           quick_basis%katom(jshell) = i
                           quick_basis%kstart(jshell) = jbasis
                           kmin(jshell) = 5
                           kmax(jshell) = 10
                           ktypecp(jshell) = 3
                           do k = 1, iprim
                              read (ibasiscustfile, '(A80)', iostat=iofile) line
                              read (line, *) aex(jbasis), gcd(jbasis)
                              jbasis = jbasis + 1
                           enddo
                           jshell = jshell + 1
                        elseif (shell == 'F') then
                           quick_basis%ktype(jshell) = 10
                           quick_basis%katom(jshell) = i
                           quick_basis%kstart(jshell) = jbasis
                           kmin(jshell) = 11
                           kmax(jshell) = 20
                           ktypecp(jshell) = 4
                           do k = 1, iprim
                              read (ibasiscustfile, '(A80)', iostat=iofile) line
                              read (line, *) aex(jbasis), gcf(jbasis)
                              jbasis = jbasis + 1
                           enddo
                           jshell = jshell + 1
                        endif
                     enddo
                  endif
               endif
            enddo
            rewind ibasiscustfile
         end if
999   enddo

      quick_basis%ksumtype(jshell) = Ninitial + 1
      jshell = jshell - 1
      jbasis = jbasis - 1

      close (ibasisfile)
      close (ibasiscustfile)

      maxcontract = 1

      do i = 1, nshell
         if (quick_basis%kprim(i) > maxcontract) maxcontract = quick_basis%kprim(i)
      enddo

      !======== MPI/MASTER ====================
   endif masterwork_readfile
   !======== END MPI/MASTER ================

#ifdef MPI
   !======== MPI/ALL NODES ====================
   if (bMPI) then
      call MPI_BCAST(maxcontract, 1, mpi_integer, 0, MPI_COMM_WORLD, mpierror)
   endif
   !======== END MPI/ALL NODES ================
#endif

   allocate (aexp(maxcontract, nbasis))
   allocate (dcoeff(maxcontract, nbasis))
   allocate (gauss(nbasis))

   !======== MPI/MASTER ====================
   masterwork_setup: if (master) then
      !======== END MPI/MASTER ====================

      ! do i=1,nbasis
      !     allocate(gauss(i)%aexp(maxcontract))
      !     allocate(gauss(i)%dcoeff(maxcontract))
      ! enddo

      ! Still support the old style of storing the basis but only for
      ! S,SP,P, and D
      l = 1
      do i = 1, nshell
         do j = 1, quick_basis%ktype(i)
            quick_basis%ncenter(l) = quick_basis%katom(i)
            ncontract(l) = quick_basis%kprim(i)
            if (quick_basis%ktype(i) == 1) then
               itype(:, l) = 0
            elseif (quick_basis%ktype(i) == 3) then
               itype(j, l) = 1
            elseif (quick_basis%ktype(i) == 4) then
               if (j > 1) then
                  itype(j - 1, l) = 1
               endif
            elseif (quick_basis%ktype(i) == 6) then

               ! New Version for QUICK

               if (j == 1) then
                  itype(:, l) = (/2, 0, 0/)
               elseif (j == 2) then
                  itype(:, l) = (/1, 1, 0/)
               elseif (j == 3) then
                  itype(:, l) = (/0, 2, 0/)
               elseif (j == 4) then
                  itype(:, l) = (/1, 0, 1/)
               elseif (j == 5) then
                  itype(:, l) = (/0, 1, 1/)
               elseif (j == 6) then
                  itype(:, l) = (/0, 0, 2/)
               end if

               ! Version for comparison with G03
               !
               !        if (j==1) then
               !          itype(:,l) = (/2,0,0/)
               !        elseif (j==2) then
               !          itype(:,l) = (/0,2,0/)
               !        elseif(j==3) then
               !          itype(:,l) = (/0,0,2/)
               !        elseif(j==4) then
               !          itype(:,l) = (/1,1,0/)
               !        elseif(j==5) then
               !          itype(:,l) = (/1,0,1/)
               !        elseif(j==6) then
               !          itype(:,l) = (/0,1,1/)
               !        end if

               ! Old Version
               !        if (j==1) then
               !          itype(:,l) = (/1,1,0/)
               !        elseif (j==2) then
               !          itype(:,l) = (/0,1,1/)
               !        elseif(j==3) then
               !          itype(:,l) = (/1,0,1/)
               !        elseif(j==4) then
               !          itype(:,l) = (/2,0,0/)
               !        elseif(j==5) then
               !          itype(:,l) = (/0,2,0/)
               !        elseif(j==6) then
               !          itype(:,l) = (/0,0,2/)
               !
               !       endif

            elseif (quick_basis%ktype(i) == 10) then

               ! New Version for QUICK

               if (j == 1) then
                  itype(:, l) = (/3, 0, 0/)
               elseif (j == 2) then
                  itype(:, l) = (/2, 1, 0/)
               elseif (j == 3) then
                  itype(:, l) = (/1, 2, 0/)
               elseif (j == 4) then
                  itype(:, l) = (/0, 3, 0/)
               elseif (j == 5) then
                  itype(:, l) = (/2, 0, 1/)
               elseif (j == 6) then
                  itype(:, l) = (/1, 1, 1/)
               elseif (j == 7) then
                  itype(:, l) = (/0, 2, 1/)
               elseif (j == 8) then
                  itype(:, l) = (/1, 0, 2/)
               elseif (j == 9) then
                  itype(:, l) = (/0, 1, 2/)
               elseif (j == 10) then
                  itype(:, l) = (/0, 0, 3/)
               end if

            endif
            ll = 1
            do k = quick_basis%kstart(i), (quick_basis%kstart(i) + quick_basis%kprim(i)) - 1
               aexp(ll, l) = aex(k)
               if (quick_basis%ktype(i) == 1) then
                  dcoeff(ll, l) = gcs(k)
               elseif (quick_basis%ktype(i) == 3) then
                  dcoeff(ll, l) = gcp(k)
               elseif (quick_basis%ktype(i) == 4) then
                  if (j == 1) then
                     dcoeff(ll, l) = gcs(k)
                  else
                     dcoeff(ll, l) = gcp(k)
                  endif
               elseif (quick_basis%ktype(i) == 6) then
                  dcoeff(ll, l) = gcd(k)
               elseif (quick_basis%ktype(i) == 10) then
                  dcoeff(ll, l) = gcf(k)
               endif
               ll = ll + 1
            enddo
            l = l + 1
         enddo
      enddo

      ! ifisrt and last_basis_function records the first and last basis set for atom i
      !
      iatm = 1
      is = 0
      quick_basis%first_basis_function(1) = 1
      do i = 1, nshell
         is = is + quick_basis%ktype(i)
         if (quick_basis%katom(i) /= iatm) then
            iatm = quick_basis%katom(i)
            quick_basis%first_basis_function(iatm) = is
            quick_basis%last_basis_function(iatm - 1) = is - 1
         endif
      enddo
      quick_basis%last_basis_function(iatm) = nbasis

      !======== MPI/MASTER ====================
   endif masterwork_setup
   !======== MPI/MASTER ====================

#ifdef MPI
   !======== MPI/ALL NODES ====================
   if (bMPI) then
      call mpi_setup_basis
      allocate (mpi_jshelln(0:mpisize - 1))
      allocate (mpi_jshell(0:mpisize - 1, jshell))

      allocate (mpi_nbasisn(0:mpisize - 1))
      allocate (mpi_nbasis(0:mpisize - 1, nbasis))

   endif
   !======== END MPI/ALL NODES ====================
#endif

   if (quick_method%debug .and. master) call debugBasis

   deallocate (aex)
   deallocate (gcs)
   deallocate (gcp)
   deallocate (gcd)
   deallocate (gcf)
   deallocate (gcg)
end subroutine

subroutine store_basis_to_ecp()
   use quick_basis_module
   use quick_ecp_module
   integer iicont, icontb
   iicont = 0
   icontb = 1
   do i = 1, nshell
      do j = 1, quick_basis%kprim(i)
         iicont = iicont + 1
         eta(iicont) = dcoeff(j, icontb)
      end do
      icontb = icontb + quick_basis%ktype(i)
   end do
end subroutine

