module balmod
!$$$   module documentation block
!                .      .    .                                       .
! module:    balmod          contains balance related stuff
!   prgmmr: parrish          org: np22                date: 2005-01-22
!
! abstract: contains routines for loading and using balance parameters
!             which define "slow" part of control variable,
!             specifically the stream function dependent part of
!             temperature, surface pressure, and velocity potential.
!
! program history log:
!   2005-01-22  parrish
!   2005-05-24  pondeca - accommodate 2dvar only surface analysis option
!   2005-07-15  wu - include fstat, f1 and fix l2
!   2008-10-08  derber include routines strong_bk and strong_bk_ad
!   2009-06-15  parrish - add logical l_hyb_ens to balance, tbalance so strong constraint
!                          can be turned off in these routines when running in hybrid ensemble mode
!                         (strong constraint gets moved to control2state and control2state_ad routines
!                            when l_hyb_ens=.true.)
!   2010-03-04  zhu  - add horizontally interpolated agvk,wgvk,bvk for regional
!   2011-09-07  todling - note that implementation of hybrid in sqrt-B case
!                         does not follow Dave's statement above (2009-06-15)
!   2012-02-08  kleist - remove ref to l_hyb_ens in subroutines balance, tbalance, strong_bk, 
!                          and strong_bk_ad.  add new parameter tlnmc_option.
!   2012-02-08  parrish - replace nn_i_kind with nn, for nn any integer.
!   2012-10-09  Gu - add fut2ps to project unbalanced temp to surface pressure in static B modeling
!   2016-08-24  lippi - Add namelist variable lnobalance to run univariate 
!                       analysis and init_balmod to initialize the variable. 
!   2021-01-25  Y. Wang and X. Wang - added codes to assign the balance operators for 
!                                     convective-scale static BECs, POC: xuguang.wang@ou.edu
!
! subroutines included:
!   sub create_balance_vars      - create arrays for balance vars
!   sub destroy_balance_vars     - remove arrays for balance vars
!   sub create_balance_vars_reg  - create arrays for regional balance vars
!   sub destroy_balance_vars_reg - remove arrays for regional balance vars
!   sub prebal                   - load balance vars
!   sub prebal_reg               - load regional balance vars
!   sub balance                  - balance routine
!   sub tbalance                 - adjoint of balance
!   sub locatelat_reg            - get interp vars for lat var --> regional grid
!   sub strong_bk                - apply strong balance constraint in background error matrix
!   sub strong_bk_ad             - apply adjoint of strong balance constraint in background error matrix
!
! Variable Definitions:
!   def agvz      - projection of streamfunction onto balanced temperature
!   def wgvz      - projection of streamfunction onto balanced ln(ps)
!   def bvz       - projection of streamfunction onto velocity potential
!   def ke_vp     - index of level above which to not let stream function
!                    influence velocity potential
!   def rllat     - lat of each regional grid point in lat grid units
!   def rllat1    - same as rllat, but for subdomains
!   def f1        - sin(lat)/sin(mid lat) for subdomains
!   def llmin     - min lat index for lat dependent background error, balance vars
!   def llmax     - max lat index for lat dependent background error, balance vars
!   def fstat     - .true. to seperate f from bal projection in regional mode
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$ end documentation block

  use kinds, only: r_kind,i_kind
  implicit none

! set default to private
  private
! set subroutines to public
  public :: init_balmod
  public :: create_balance_vars
  public :: destroy_balance_vars
  public :: create_balance_vars_reg
  public :: destroy_balance_vars_reg
  public :: prebal
  public :: prebal_reg
  public :: balance
  public :: tbalance
  public :: locatelat_reg
  public :: strong_bk
  public :: strong_bk_ad
! set passed variables to public
  public :: fstat,llmax,llmin,rllat,rllat1,ke_vp,f1,bvz,agvz,wgvz,bvk,agvk,wgvk,agvk_lm
  public :: pput
  public :: lnobalance

  ! ywang >
  public :: balance_extra
  public :: tbalance_extra
  public :: evik2, evik3, evik2_real, evik3_real
  public :: extra_var2num, extra_var3num
  ! ywang <

  real(r_kind),allocatable,dimension(:,:,:):: agvz
  real(r_kind),allocatable,dimension(:,:):: wgvz
  real(r_kind),allocatable,dimension(:,:):: pput
  real(r_kind),allocatable,dimension(:,:):: bvz
  real(r_kind),allocatable,dimension(:,:,:,:):: agvk
  real(r_kind),allocatable,dimension(:,:):: agvk_lm
  real(r_kind),allocatable,dimension(:,:,:):: wgvk
  real(r_kind),allocatable,dimension(:,:,:):: bvk
  real(r_kind),allocatable   :: rllat(:,:),rllat1(:,:),f1(:,:)

  ! ywang >
  real(r_kind),allocatable,dimension(:,:,:,:)  :: evik2, evik2_real
  real(r_kind),allocatable,dimension(:,:,:,:,:):: evik3, evik3_real
  integer(i_kind) extra_var2num, extra_var3num
  ! ywang <

  integer(i_kind) ke_vp
  integer(i_kind) llmin,llmax
  logical fstat,lnobalance

contains

  subroutine init_balmod
  implicit none
  lnobalance=.false.
  end subroutine init_balmod


  subroutine create_balance_vars
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    create_balance_vars    create arrays for balance vars
!   prgmmr: parrish          org: np22                date: 2005-01-22
!
! abstract: creates arrays for balance variables
!
! program history log:
!   2005-01-22  parrish
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use gridmod, only: lat2,nsig
    implicit none
    
    allocate(agvz(lat2,nsig,nsig),wgvz(lat2,nsig),bvz(lat2,nsig))
    allocate(pput(lat2,nsig))
    
    return
  end subroutine create_balance_vars
  
  subroutine destroy_balance_vars
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    destroy_balance_vars  deallocates balance var arrays
!   prgmmr: parrish          org: np22                date: 2005-01-22
!
! abstract: deallocates balance var arrays
!
! program history log:
!   2005-01-22  parrish
!   2005-03-03  treadon - add implicit none
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    implicit none

    deallocate(agvz,wgvz,bvz)
    deallocate(pput)

    return
  end subroutine destroy_balance_vars

  subroutine create_balance_vars_reg(mype)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    create_balance_vars_reg  create arrays for reg balance vars
!   prgmmr: parrish          org: np22                date: 2005-01-22
!
! abstract: create arrays for regional balance vars
!
! program history log:
!   2005-01-22  parrish
!   2008-11-13  zhu - replace agvz,wgvz and bvz by interpolated agvk,wgvk,bvk
!
!   input argument list:
!    mype
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use gridmod, only: nlat,nlon,nsig,lat2,lon2
    use obsmod, only: if_cs_staticB
    implicit none

    integer(i_kind),intent(in   ) :: mype

! ywang >
    integer(i_kind)          :: extra_vartotnum, extra_var2num,extra_var3num,&
                                ii,jj,kk
    logical                  :: if_exist
    character(len=1024)      :: varname

   if( if_cs_staticB )then
     inquire( file='regcoeff.txt', exist=if_exist )
     if( if_exist )then
       extra_var2num = 0
       extra_var3num = 0
       open(55, file='regcoeff.txt', action='read')
         read(55,*)extra_vartotnum
         do ii = 1, extra_vartotnum
           read(55,*)varname,jj
           if( jj < 3  ) then
             extra_var2num = extra_var2num + 1
           end if
           if( jj == 3 ) then
             extra_var3num = extra_var3num + 1
           end if
         end do

         if( extra_var3num + extra_var2num .ne. extra_vartotnum ) STOP 'Wrong with the number of extra_var'
       close(55)
     else
       write(*,*)'Cannot find regcoeff.txt'
       STOP 2
     endif
   endif

! ywang <

!         compute rllat, rllat1, llmin, llmax
    allocate(rllat(nlat,nlon))
    allocate(rllat1(lat2,lon2))
    allocate(f1(lat2,lon2))
    call locatelat_reg(mype)
    
    allocate(agvk(lat2,lon2,nsig,nsig),agvk_lm(nsig,nsig), &
             wgvk(lat2,lon2,nsig),bvk(lat2,lon2,nsig))

! ywang >
    if( if_cs_staticB )then

      allocate(evik2_real(extra_var2num,lat2,lon2,nsig))
      allocate(evik3_real(extra_var3num,lat2,lon2,nsig,nsig))

      allocate(evik2(11,lat2,lon2,nsig))
      allocate(evik3(55,lat2,lon2,nsig,nsig))

      evik2 = 0.0_r_kind
      evik3 = 0.0_r_kind
    end if
! ywang <
    
    return
  end subroutine create_balance_vars_reg

  subroutine destroy_balance_vars_reg
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    destroy_balance_vars_reg  deallocate reg balance var arrays
!   prgmmr: parrish          org: np22                date: 2005-01-22
!
! abstract: deallocate regional balance variable arrays
!
! program history log:
!   2005-01-22  parrish
!   2005-03-03  treadon - add implicit none
!   2010-03-04  zhu - change agvz,wgvz and bvz to agvk,wgvk,bvk
!
!   input argument list:
!
!   output argument list:
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use obsmod, only: if_cs_staticB
    implicit none

    deallocate(rllat,rllat1,f1,agvk,agvk_lm,wgvk,bvk)

    ! ywang >
    if( if_cs_staticB )then
      deallocate(evik2)
      deallocate(evik3)
  
      deallocate(evik2_real)
      deallocate(evik3_real)
    end if
    ! ywang <

    return
  end subroutine destroy_balance_vars_reg

  subroutine prebal(fut2ps,cwcoveqqcov)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    prebal
!   prgmmr: wu               org: np22                date: 2000-03-15
!
! abstract: load balance variables agvz, bvz, wgvz, and ke_vp
!
! program history log:
!   2000-03-15  wu           
!   2004-02-03  kleist, updated to load background stats according
!               to updated mpi distribution on horizontal slabs
!   2004-03-15  derber, kleist, incorporate variances into this routine
!               stats from single file, additional clean up
!   2004-05-17  kleist, documentation and clean up
!   2004-08-03  treadon - add only to module use, add intent in/out
!   2004-10-26  wu - include factors hzscl in the range of RF table
!   2004-11-02  treadon - add horizontal resolution error check on berror_stats
!   2004-11-16  treadon - add longitude dimension to variance array dssv
!   2004-11-20  derber - modify to make horizontal table more reproducable and  
!               move most of table calculations to berror 
!   2005-01-22  parrish - split off from old prewgt
!   2005-03-28  wu - replace mlath with mlat            
!   2005-04-14  treadon - add corq2 to global berror_stats read
!   2005-04-22  treadon - change berror file to 4-byte reals
!   2006-04-17  treadon - remove calculation of ke_vp
!   2007-05-30  h.liu   - add coroz
!   2008-07-10  jguo    - place read of bkgerr fields in m_berror_stats
!   2008-12-29  todling - get mlat from dims in m_berror_stats; mype from mpimod
!   2009-02-25  zhu     - remove the error message
!   2014-02-05  todling - add parameter to control overwrite of cw w/ q cov
!
!   input argument list:
!
!   output argument list:
!
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use kinds, only: r_single
    use mpimod, only: mype
    use gridmod, only: istart,lat2,nlat,nsig
    use constants, only: zero
    use m_berror_stats,only: berror_set,berror_read_bal
    implicit none
    
    logical              ,intent(in   ) :: fut2ps
    logical              ,intent(in   ) :: cwcoveqqcov

!   Declare local variables
    integer(i_kind) i,j,k
    integer(i_kind) mm1
    integer(i_kind) jx
    
    real(r_single),dimension(nlat,nsig,nsig):: agvin
    real(r_single),dimension(nlat,nsig) :: wgvin,bvin
    real(r_single),dimension(nlat,nsig) :: pputin
    
!   Initialize local variables
    mm1=mype+1

!   Set internal parameters to m_berror_stats
    call berror_set('cwcoveqqcov',cwcoveqqcov)

!   Read in balance variables
    call berror_read_bal(agvin,bvin,wgvin,pputin,fut2ps,mype)

!   Set ke_vp=nsig (note:  not used in global)
    ke_vp=nsig
    
!   load balance projections
    agvz=zero
    bvz=zero
    wgvz=zero
    pput=zero
    do k=1,nsig
       do j=1,nsig
          do i=1,lat2
             jx=istart(mm1)+i-2
             jx=max(jx,2)
             jx=min(nlat-1,jx)
             agvz(i,j,k)=agvin(jx,j,k)
          end do
       end do
       do i=1,lat2
          jx=istart(mm1)+i-2
          jx=max(jx,2)
          jx=min(nlat-1,jx)
          wgvz(i,k)=wgvin(jx,k)
          bvz(i,k)=bvin(jx,k)
          pput(i,k)=pputin(jx,k)
       end do
    enddo

    return
  end subroutine prebal

  subroutine prebal_reg(cwcoveqqcov)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    prebal_reg  setup balance vars
!   prgmmr: wu               org: np22                date: 2000-03-15
!
! abstract: load balance variables agvz, bvz, wgvz, and ke_vp
!
! program history log:
!   2000-03-15  wu
!   2004-08-03  treadon - add only to module use; add intent in/out;
!                         fix bug in which rdgstat_reg inadvertently
!                         recomputed sigl (s/b done in gridmod)
!   2004-10-26  wu - include factors hzscl in the range of RF table
!   2004-11-16  treadon - add longitude dimension to variance array dssv
!   2004-11-20  derber - modify to make horizontal table more reproducable and
!               move most of table calculations to berror
!   2005-01-23  parrish - split off from old prewgt_reg
!   2005-02-07  treadon - add deallocate(corz,corp,hwll,hwllp,vz,agvi,bvi,wgvi)
!   2005-03-28  wu - replace mlath with mlat and modify dim of corz, corp
!   2006-04-17  treadon - replace sigl with ges_prslavg/ges_psfcavg 
!   2008-11-13  zhu - add changes for generalized control variables
!                   - change the structure of covariance error file
!                   - move horizontal interpolation into this subroutine
!   2014-10-08  zhu - add cwcoveqqco in the interface 
!
!   input argument list:
!
!   output argument list:
!
!   other important variables
!     nsig     - number of sigma levels
!   agv,wgv,bv - balance correlation matrix for t,p,div

! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!$$$
    use gridmod, only: lat2,lon2,nsig,twodvar_regional
    use guess_grids, only: ges_prslavg,ges_psfcavg
    use mpimod, only: mype
    use m_berror_stats_reg, only: berror_set_reg,berror_get_dims_reg,berror_read_bal_reg
    use constants, only: zero,half,one
    use m_berror_stats_reg, only: berror_read_bal_reg_extra,berror_get_dims_reg_extra ! ywang
    use gsi_bundlemod, only: gsi_bundlegetpointer   ! ywang
    use gsi_metguess_mod, only: gsi_metguess_bundle ! ywang
    use obsmod, only : if_cs_staticB
    implicit none

!   Declare passed variables
    logical,intent(in   ) :: cwcoveqqcov

!   Declare local parameters
    real(r_kind),parameter:: r08 = 0.8_r_kind

!   Declare local variables
    integer(i_kind) k,i,mlat
    integer(i_kind) j,m,lm,l,l2
    integer(i_kind) ke,inerr
    integer(i_kind) msig                   ! stats dimensions

    real(r_kind):: psfc08
    real(r_kind):: dl1,dl2
    real(r_kind),allocatable,dimension(:,:):: wgvi ,bvi
    real(r_kind),allocatable,dimension(:,:,:):: agvi

! ywang >
    integer(i_kind) num_bins2d,ivar
    real(r_kind),allocatable,dimension(:,:,:,:)  :: evi2
    real(r_kind),allocatable,dimension(:,:,:,:,:):: evi3 

    integer(i_kind)          :: extra_vartotnum,ii,jj,kk,varinfulllist,istatus
    logical                  :: if_exist
    character(len=1024)      :: varname
    character(len=1024),dimension(200)      :: varname3, varname2
    real(r_kind),dimension(:,:,:),pointer::ges_mask=>NULL()

    if ( if_cs_staticB )then
      inquire( file='regcoeff.txt', exist=if_exist )
      if( if_exist )then
        extra_var2num = 0
        extra_var3num = 0
        open(55, file='regcoeff.txt', action='read')
          read(55,*)extra_vartotnum
          do ii = 1, extra_vartotnum
            read(55,*)varname,jj
            if( jj < 3  ) then
              extra_var2num = extra_var2num + 1
              varname2(extra_var2num) = varname
            end if
            if( jj == 3 ) then
              extra_var3num = extra_var3num + 1
              varname3(extra_var3num) = varname
            end if
          end do

          if( extra_var3num + extra_var2num .ne. extra_vartotnum ) STOP 'Wrong with the number of extra_var'
        close(55)
      else
        write(*,*)'Cannot find regcoeff.txt'
        STOP 2
      endif
    endif

! ywang <

!   Set internal parameters to m_berror_stats
    call berror_set_reg('cwcoveqqcov',cwcoveqqcov)

!   Read dimension of stats file
    inerr=22
    if( if_cs_staticB )then  ! ywang
       call berror_get_dims_reg_extra(msig,mlat,num_bins2d)
    else
       call berror_get_dims_reg(msig,mlat)
    end if

!   Allocate arrays in stats file
    allocate ( agvi(0:mlat+1,1:nsig,1:nsig) )
    allocate ( bvi(0:mlat+1,1:nsig),wgvi(0:mlat+1,1:nsig) )

!   Read in background error stats and interpolate in vertical to that specified in namelist
    if( if_cs_staticB )then  ! ywang
      allocate ( evi2(15,0:mlat+1,num_bins2d,1:nsig) )
      allocate ( evi3(60,0:mlat+1,num_bins2d,1:nsig,1:nsig) )
      call berror_read_bal_reg_extra(msig,mlat,num_bins2d,agvi,bvi,wgvi,evi2,evi3,mype,inerr)
    else
      call berror_read_bal_reg(msig,mlat,agvi,bvi,wgvi,mype,inerr)
    end if
    
!   ke_vp used to project SF to balanced VP
!   below sigma level 0.8

    psfc08=r08*ges_psfcavg
    ke=nsig
    j_loop: do j=1,nsig
       if (ges_prslavg(j)<psfc08) then
          ke=j
          exit j_loop
       endif
    enddo j_loop
    
    agvk=zero
    bvk=zero
    wgvk=zero
    ke_vp=ke-1
    if (twodvar_regional) ke_vp=ke
    if (.not.twodvar_regional) then
       do k=1,ke_vp
          do j=1,lon2
             do i=1,lat2
                l=int(rllat1(i,j))
                l2=min0(l+1,llmax)
                dl2=rllat1(i,j)-float(l)
                dl1=one-dl2
                bvk(i,j,k)=dl1*bvi(l,k)+dl2*bvi(l2,k)
             end do
          end do
       end do
       do k=ke_vp+1,nsig
          do j=1,lon2
             do i=1,lat2
                bvk(i,j,k)=zero
             enddo
          enddo
       enddo

       lm=(llmax+llmin)*half
       do k=1,nsig
          do m=1,nsig
             agvk_lm(m,k)=agvi(lm,m,k)
             do j=1,lon2
                do i=1,lat2
                   l=int(rllat1(i,j))
                   l2=min0(l+1,llmax)
                   dl2=rllat1(i,j)-float(l)
                   dl1=one-dl2
                   agvk(i,j,m,k)=dl1*agvi(l,m,k)+dl2*agvi(l2,m,k)
                end do
             end do
          end do
       end do
       do k=1,nsig
          do j=1,lon2
             do i=1,lat2
                l=int(rllat1(i,j))
                l2=min0(l+1,llmax)
                dl2=rllat1(i,j)-float(l)
                dl1=one-dl2
                wgvk(i,j,k)=dl1*wgvi(l,k)+dl2*wgvi(l2,k)
             end do
          end do
       end do
      
! ymwang >
       if( if_cs_staticB )then
          call gsi_bundlegetpointer(gsi_metguess_bundle(1),'mask',ges_mask,istatus)
          do ivar = 1, extra_var2num
          do k=1,nsig
             do j=1,lon2
                do i=1,lat2
                   l=int(rllat1(i,j))
                   l2=min0(l+1,llmax)
                   dl2=rllat1(i,j)-float(l)
                   dl1=one-dl2
                   if( ges_mask(i,j,k) < -0.5_r_kind   )then
                      evik2_real(ivar,i,j,k)=dl1*evi2(ivar,l,2,k)+dl2*evi2(ivar,l2,2,k)
                   else if ( ges_mask(i,j,k) > 0.5_r_kind  )then
                      evik2_real(ivar,i,j,k)=dl1*evi2(ivar,l,3,k)+dl2*evi2(ivar,l2,3,k)
                   else
                      evik2_real(ivar,i,j,k)=dl1*evi2(ivar,l,1,k)+dl2*evi2(ivar,l2,1,k)
                   end if
                end do
             end do
          end do
          varinfulllist = 0
          call fulllist_var_rh( varname2(ivar), 2, varinfulllist )
          if( varinfulllist > 0 )then
            evik2(varinfulllist,:,:,:) = evik2_real(ivar,:,:,:)
          else
            evik2(varinfulllist,:,:,:) = 0.0_r_kind
          end if
          if(mype==0) print*, varinfulllist, 'varinfulllist2',trim(varname2(ivar))
          end do


          do ivar = 1, extra_var3num
          do k=1,nsig
             do m=1,nsig
                do j=1,lon2
                   do i=1,lat2
                      l=int(rllat1(i,j))
                      l2=min0(l+1,llmax)
                      dl2=rllat1(i,j)-float(l)
                      dl1=one-dl2
                      if( ges_mask(i,j,k) < -0.5_r_kind  )then
                        evik3_real(ivar,i,j,m,k)=dl1*evi3(ivar,l,2,m,k)+dl2*evi3(ivar,l2,2,m,k)
                      else if ( ges_mask(i,j,k) > 0.5_r_kind  )then
                        evik3_real(ivar,i,j,m,k)=dl1*evi3(ivar,l,3,m,k)+dl2*evi3(ivar,l2,3,m,k)
                      else
                        evik3_real(ivar,i,j,m,k)=dl1*evi3(ivar,l,1,m,k)+dl2*evi3(ivar,l2,1,m,k)
                      end if
                   end do
                end do
             end do
          end do
          varinfulllist = 0
          call fulllist_var_rh( varname3(ivar), 3, varinfulllist )
          if( varinfulllist > 0 )then
            evik3(varinfulllist,:,:,:,:) = evik3_real(ivar,:,:,:,:)
          else
            evik3(varinfulllist,:,:,:,:) = 0.0_r_kind
          end if
          if(mype==0) print*, varinfulllist, 'varinfulllist3',trim(varname3(ivar))
          end do

       end if
! ymwang <
    endif


!   Alternatively, zero out all balance correlation matrices
!   for univariate surface analysis
    if (twodvar_regional .or. lnobalance) then
       if(mype==0) write(6,*)"***WARNING*** running univariate analysis." 
       bvk(:,:,:)=zero
       agvk(:,:,:,:)=zero
       wgvk(:,:,:)=zero
       if(lnobalance) agvk_lm(:,:)=zero
    endif
    
    deallocate (agvi,bvi,wgvi)

    if( if_cs_staticB )  deallocate(evi3,evi2)
    
    return
  end subroutine prebal_reg

  subroutine fulllist_var_rh( varname, flag, varinlist )
    implicit none
    character(len=1024)       :: varname
    integer                   :: flag, varinlist

    if( flag > 2 ) then

      select case(trim(varname))
        case("regcoeff_u_v")
          varinlist=1
        case("regcoeff_u_t")
          varinlist=2
        case("regcoeff_u_rh")
          varinlist=3
        case("regcoeff_u_w")
          varinlist=4
        case("regcoeff_u_qcloud")
          varinlist=5
        case("regcoeff_u_qice")
          varinlist=6
        case("regcoeff_u_qrain")
          varinlist=7
        case("regcoeff_u_qsnow")
          varinlist=8
        case("regcoeff_u_qgraup")
          varinlist=9
        case("regcoeff_u_dbz")
          varinlist=10
        case("regcoeff_v_u_t")
          varinlist=11
        case("regcoeff_v_u_rh")
          varinlist=12
        case("regcoeff_v_u_w")
          varinlist=13
        case("regcoeff_v_u_qcloud")
          varinlist=14
        case("regcoeff_v_u_qice")
          varinlist=15
        case("regcoeff_v_u_qrain")
          varinlist=16
        case("regcoeff_v_u_qsnow")
          varinlist=17
        case("regcoeff_v_u_qgraup")
          varinlist=18
        case("regcoeff_v_u_dbz")
          varinlist=19
        case("regcoeff_t_u_rh")
          varinlist=20
        case("regcoeff_t_u_w")
          varinlist=21
        case("regcoeff_t_u_qcloud")
          varinlist=22
        case("regcoeff_t_u_qice")
          varinlist=23
        case("regcoeff_t_u_qrain")
          varinlist=24
        case("regcoeff_t_u_qsnow")
          varinlist=25
        case("regcoeff_t_u_qgraup")
          varinlist=26
        case("regcoeff_t_u_dbz")
          varinlist=27
        case("regcoeff_rh_u_w")
          varinlist=28
        case("regcoeff_rh_u_qcloud")
          varinlist=29
        case("regcoeff_rh_u_qice")
          varinlist=30
        case("regcoeff_rh_u_qrain")
          varinlist=31
        case("regcoeff_rh_u_qsnow")
          varinlist=32
        case("regcoeff_rh_u_qgraup")
          varinlist=33
        case("regcoeff_rh_u_dbz")
          varinlist=34
        case("regcoeff_w_u_qcloud")
          varinlist=35
        case("regcoeff_w_u_qice")
          varinlist=36
        case("regcoeff_w_u_qrain")
          varinlist=37
        case("regcoeff_w_u_qsnow")
          varinlist=38
        case("regcoeff_w_u_qgraup")
          varinlist=39
        case("regcoeff_w_u_dbz")
          varinlist=40
        case("regcoeff_qcloud_u_qice")
          varinlist=41
        case("regcoeff_qcloud_u_qrain")
          varinlist=42
        case("regcoeff_qcloud_u_qsnow")
          varinlist=43
        case("regcoeff_qcloud_u_qgraup")
          varinlist=44
        case("regcoeff_qcloud_u_dbz")
          varinlist=45
        case("regcoeff_qice_u_qrain")
          varinlist=46
        case("regcoeff_qice_u_qsnow")
          varinlist=47
        case("regcoeff_qice_u_qgraup")
          varinlist=48
        case("regcoeff_qice_u_dbz")
          varinlist=49
        case("regcoeff_qrain_u_qsnow")
          varinlist=50
        case("regcoeff_qrain_u_qgraup")
          varinlist=51
        case("regcoeff_qrain_u_dbz")
          varinlist=52
        case("regcoeff_qsnow_u_qgraup")
          varinlist=53
        case("regcoeff_qsnow_u_dbz")
          varinlist=54
        case("regcoeff_qgraup_u_dbz")
          varinlist=55

      end select

    else

      select case(trim(varname))
        case("regcoeff_u_ps")
          varinlist = 1
        case("regcoeff_v_u_ps")
          varinlist = 2
        case("regcoeff_t_u_ps")
          varinlist = 3
        case("regcoeff_ps_u_rh")
          varinlist = 4
        case("regcoeff_ps_u_w")
          varinlist = 5
        case("regcoeff_ps_u_qcloud")
          varinlist = 6
        case("regcoeff_ps_u_qice")
          varinlist = 7
        case("regcoeff_ps_u_qrain")
          varinlist = 8
        case("regcoeff_ps_u_qsnow")
          varinlist = 9
        case("regcoeff_ps_u_qgraup")
          varinlist = 10
        case("regcoeff_ps_u_dbz")
          varinlist = 11
      end select

    end if

end subroutine fulllist_var_rh
  
  subroutine balance(t,p,st,vp,fpsproj,fut2ps)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    balance     apply balance equation
!
!   prgmmr: parrish          org: np22                date: 1990-10-06
!
! abstract: balance equation and conversion from streamfunction 
!           and velocity potential to uv
!
! program history log:
!   1990-10-06  parrish
!   1994-02-02  parrish
!   1997-12-03  weiyu yang
!   1999-06-28  yang w., second structure mpp version
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   1999-12-07  wu               grid version
!   2003-12-22  derber 
!   2004-02-03  kleist, new mpi strategy
!   2004-05-06  derber separate out balance equation from vertical correlation
!   2004-07-28  treadon - add only on use declarations; add intent in/out
!   2004-10-26  kleist - remove u,v - st,vp conversion outside of bkerror, modified
!               ps balance 
!   2005-02-23  wu - add variable conversion for normalized relative humidity        
!   2005-03-05  parrish - for qoption=2, leave q unchanged, so in/out is normalized rh
!   2005-06-06  wu - use f1 in balance projection (st->t) when fstat=.true.
!   2005-07-14  wu - add max bound to l2
!   2005-11-21  derber modify to make qoption =1 work same as =2
!   2006-01-11  kleist - add full nsig projection for surface pressure
!   2006-10-15  gu - add back vp projection onto surface pressure
!   2006-11-30  todling - add fpsproj to control diff projection contributions to ps  
!   2008-06-05  safford - rm unused vars
!   2008-12-29  todling - remove q from arg list
!   2010-03-09  zhu     - move the interpolation for regional to prebal_reg
!   2011-09-07  todling - in sqrt-b case, always apply balance (even in hyb mode) 
!   2012-02-08  kleist  - replace "use hybrid_ensemble_parameters, only: l_hyb_ens"
!                           with   "use mod_strong, only: tlnmc_option".
!                           then trigger call to strong_bk at end of subroutine balance with 
!                           new parameter tlnmc_option and add uvflag=.false. to call strong_bk.
!
!   input argument list:
!     t        - t grid values 
!     p        - p surface grid values 
!     st       - streamfunction grid values 
!     vp       - velocity potential grid values 
!     fpsproj
!
!   output argument list:
!     t        - t grid values 
!     p        - p surface grid values 
!     st       - streamfunction grid values 
!     vp       - velocity potential grid values 
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use constants, only: one,half
    use gsi_4dvar, only: lsqrtb
    use gridmod, only: regional,lat2,nsig,lon2
    use mod_strong, only: tlnmc_option
    implicit none
    
!   Declare passed variables
    real(r_kind),dimension(lat2,lon2)     ,intent(inout) :: p
    real(r_kind),dimension(lat2,lon2,nsig),intent(inout) :: t,vp,st
    logical                               ,intent(in   ) :: fpsproj
    logical                               ,intent(in   ) :: fut2ps

!   Declare local variables
    integer(i_kind) i,j,k,l,m

!   REGIONAL BRANCH
    if (regional) then

!      Add contribution from streamfunction to unbalanced velocity potential.
       do k=1,ke_vp
          do j=1,lon2
             do i=1,lat2
                vp(i,j,k)=vp(i,j,k)+bvk(i,j,k)*st(i,j,k)
             end do
          end do
       end do
       

       if (fstat) then
!      Add contribution from streamfunction to unbalanced temperature.
          do k=1,nsig
             do m=1,nsig
                do j=1,lon2
                   do i=1,lat2
                      t(i,j,k)=t(i,j,k)+agvk_lm(k,m)*f1(i,j)*st(i,j,m)
                   end do
                end do
             end do
          end do

       else ! not fstat

!      Add contribution from streamfunction to unbalanced temperature.
          do k=1,nsig
             do m=1,nsig
                do j=1,lon2
                   do i=1,lat2
                      t(i,j,k)=t(i,j,k)+agvk(i,j,k,m)*st(i,j,m)
                   end do
                end do
             end do
          end do
       endif ! fstat

!      Add contribution from streamfunction to surface pressure.
       do k=1,nsig
          do j=1,lon2
             do i=1,lat2
                p(i,j)=p(i,j)+wgvk(i,j,k)*st(i,j,k)
             end do
          end do
       end do
       
!   GLOBAL BRANCH
    else

!      Add contribution from streamfunction and unbalanced vp
!      to surface pressure.
       if ( fpsproj ) then
          do k=1,nsig
             do j=1,lon2
                do i=1,lat2
                   p(i,j)=p(i,j)+wgvz(i,k)*st(i,j,k)
                end do
             end do
          end do
          if(fut2ps) then
            do k=1,nsig
               do j=1,lon2
                  do i=1,lat2
                     p(i,j)=p(i,j)+pput(i,k)*t(i,j,k)
                  end do
               end do
            end do
          endif
       else
          do k=1,nsig-1
             do j=1,lon2
                do i=1,lat2
                   p(i,j)=p(i,j)+wgvz(i,k)*st(i,j,k)
                end do
             end do
          end do
          do j=1,lon2
             do i=1,lat2
                p(i,j)=p(i,j)+wgvz(i,nsig)*vp(i,j,1)
             end do
          end do
       endif

!$omp parallel do  schedule(dynamic,1) private(k,l,j,i)
       do k=1,nsig
!      Add contribution from streamfunction to veloc. potential
          do j=1,lon2
             do i=1,lat2
                vp(i,j,k)=vp(i,j,k)+bvz(i,k)*st(i,j,k)
             end do
          end do

!      Add contribution from streamfunction to unbalanced temperature.
          do l=1,nsig
             do j=1,lon2
                do i=1,lat2
                   t(i,j,k)=t(i,j,k)+agvz(i,k,l)*st(i,j,l)
                end do
             end do
          end do
       end do

!   End of REGIONAL/GLOBAL if-then block
    endif

!!   Strong balance constraint
!!   Pass uvflag=.false.
    if(lsqrtb) then
       call strong_bk(st,vp,p,t,.false.)
     else
       if(tlnmc_option==1 .or. tlnmc_option==4) call strong_bk(st,vp,p,t,.false.)
     endif



    return
  end subroutine balance
  
  subroutine tbalance(t,p,st,vp,fpsproj,fut2ps)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    tbalance    adjoint of balance
!   prgmmr: parrish          org: np22                date: 1994-02-12
!
! abstract: adjoint of balance equation
!
! program history log:
!   1994-02-12  parrish
!   1998-01-22  weiyu yang
!   1999-06-28  yang w., second structure mpp version
!   1999-08-24  derber, j., treadon, r., yang, w., first frozen mpp version
!   1999-12-07  wu               grid version
!   2003-12-22  derber
!   2004-02-03  kleist, new mpi strategy
!   2004-05-06  derber separate out balance from vertical covariance
!   2004-07-09  treadon - use qsatg_fix instead of qsatg in normalization of q (bug fix)
!   2004-10-26  kleist - remove u,v -- st,vp conversion oustide of bkerror, modified ps
!               balance
!   2005-02-23  wu - add adjoint of variable conversion for normalized relative humidity        
!   2005-03-05  parrish - for qoption=2, leave q unchanged, so in/out is normalized rh
!   2005-07-15  wu - use f1 in adjoint of balance projection (st->t) when fstat=.true. Add max bound to l2
!   2005-11-21  derber modify to make qoption =1 work same as =2
!   2006-01-11  kleist - add full nsig projection for surface pressure
!   2006-10-15  gu - add back vp projection onto surface pressure
!   2006-11-30  todling - add fpsproj to control diff projection contributions to ps  
!   2008-06-05  safford - rm unused vars
!   2008-12-29  todling - remove q from arg list
!   2009-06-15  parrish - add logical l_hyb_ens to balance, t_balance so strong constraint
!                          can be turned off in these routines when running in hybrid ensemble mode
!                         (strong constraint gets moved to control2state and control2state_ad routines
!                            when l_hyb_ens=.true.)
!   2010-03-09  zhu     - move the interpolation for regional to prebal_reg
!   2011-09-07  todling - in sqrt-b case, always apply balance (even in hyb mode) 
!   2012-02-08  kleist  - replace "use hybrid_ensemble_parameters, only: l_hyb_ens"
!                           with   "use mod_strong, only: tlnmc_option".
!                           then trigger call to strong_bk_ad at beginning of subroutine tbalance with 
!                           new parameter tlnmc_option and add uvflag=.false. to call strong_bk_ad.
!
!   input argument list:
!     t        - t grid values from int routines 
!     p        - p surface grid values from int routines 
!     st       - streamfunction grid values from int routines 
!     vp       - velocity potential grid values from int routines
!     fpsproj
!
!   output argument list:
!     t
!     p
!     st       - streamfunction grid vals with adjoint of balance added
!     vp       - velocity potential grid values with adjoint of balance added
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use constants,   only: one,half
    use gsi_4dvar,   only: lsqrtb
    use gridmod,     only: regional,lon2,lat2,nsig
    use mod_strong,  only: tlnmc_option
    implicit none

!   Declare passed variables
    real(r_kind),dimension(lat2,lon2)     ,intent(inout) :: p
    real(r_kind),dimension(lat2,lon2,nsig),intent(inout) :: t
    real(r_kind),dimension(lat2,lon2,nsig),intent(inout) :: st,vp
    logical                               ,intent(in   ) :: fpsproj
    logical                               ,intent(in   ) :: fut2ps

!   Declare local variables
    integer(i_kind) l,m,i,j,k

  
!  Adjoint of strong balance constraint
!  pass uvflag=.false.
    if(lsqrtb) then
       call strong_bk_ad(st,vp,p,t,.false.)
    else
       if(tlnmc_option==1 .or. tlnmc_option==4) call strong_bk_ad(st,vp,p,t,.false.)
    endif

!   REGIONAL BRANCH
    if (regional) then

       if(fstat) then
!      Adjoint of contribution to temperature from streamfunction.
          do m=1,nsig
             do k=1,nsig
                do j=1,lon2
                   do i=1,lat2
                      st(i,j,m)=st(i,j,m)+agvk_lm(k,m)*f1(i,j)*t(i,j,k)
                   end do
                end do
             end do
          end do

       else ! not fstat

!      Adjoint of contribution to temperature from streamfunction.
          do m=1,nsig
             do k=1,nsig
                do j=1,lon2
                   do i=1,lat2
                      st(i,j,m)=st(i,j,m)+agvk(i,j,k,m)*t(i,j,k)
                   end do
                end do
             end do
          end do
       endif ! fstat

!      Adjoint of streamfunction contribution to surface pressure.  
!      Add contributions from u and v to streamfunction and velocity potential
       do k=1,nsig
          do j=1,lon2
             do i=1,lat2
                st(i,j,k)=st(i,j,k)+wgvk(i,j,k)*p(i,j)
             end do
          end do
       end do

!      Adjoint of contribution to velocity potential from streamfunction.
       do k=1,ke_vp
          do j=1,lon2
             do i=1,lat2
                st(i,j,k)=st(i,j,k)+bvk(i,j,k)*vp(i,j,k)
             end do
          end do
       end do
       
!   GLOBAL BRANCH
    else

!$omp parallel do  schedule(dynamic,1) private(k,l,j,i)
       do k=1,nsig
!         Adjoint of contribution to temperature from streamfunction.
          do l=1,nsig
             do j=1,lon2
                do i=1,lat2
                   st(i,j,k)=st(i,j,k)+agvz(i,l,k)*t(i,j,l)
                end do
             end do
          end do

!         Adjoint of contribution to velocity potential from streamfunction.
          do j=1,lon2
             do i=1,lat2
                st(i,j,k)=st(i,j,k)+bvz(i,k)*vp(i,j,k)
             end do
          end do

!         Adjoint of streamfunction and unbalanced velocity potential
!         contribution to surface pressure.
          if ( fpsproj ) then
             if ( fut2ps ) then
                do j=1,lon2
                   do i=1,lat2
                      t(i,j,k)=t(i,j,k)+pput(i,k)*p(i,j)
                   end do
                end do
             endif
             do j=1,lon2
                do i=1,lat2
                   st(i,j,k)=st(i,j,k)+wgvz(i,k)*p(i,j)
                end do
             end do
          else
             if(k < nsig)then
                 do j=1,lon2
                   do i=1,lat2
                      st(i,j,k)=st(i,j,k)+wgvz(i,k)*p(i,j)
                   end do
                 end do
             end if
             if(k == 1)then
                 do j=1,lon2
                   do i=1,lat2
                     vp(i,j,1)=vp(i,j,1)+wgvz(i,nsig)*p(i,j)
                   end do
                 end do
              end if
             
          endif
       end do
!   End of REGIONAL/GLOBAL if-then block
    endif

    return
  end subroutine tbalance

  subroutine balance_extra(vor,div,ps,t,q,w,qr,qs,qg,ql,qi,dbz)
    use constants, only: one,half
    use gsi_4dvar, only: lsqrtb
    use gridmod, only: regional,lat2,nsig,lon2
    implicit none

!   Declare passed variables
    real(r_kind),dimension(lat2,lon2),intent(inout)      :: ps
    real(r_kind),dimension(lat2,lon2,nsig),intent(inout) :: vor,div,qi,ql
    real(r_kind),dimension(lat2,lon2,nsig),intent(inout) :: t,q,w,qr,qs,qg,dbz

!   Declare local variables
    integer(i_kind) i,j,k,l,m

    integer(i_kind)  :: vor_div, vor_qs, vor_t, vor_w, vor_ql,vor_qi,vor_qr,vor_qsnow,vor_qg, &
                        vor_dbz,&
                        div_qs, div_t, div_w, div_ql, div_qi, div_qr,div_qsnow,div_qg,div_dbz,&
                        t_qs,t_w,t_ql,t_qi,t_qr,t_qsnow,t_qg,t_dbz,&
                        qs_w,qs_ql,qs_qi,qs_qr,qs_qsnow,qs_qg, qs_dbz,&
                        w_ql,w_qi,w_qr,w_qsnow,w_qg,w_dbz, &
                        ql_qi,ql_qr,ql_qsnow,ql_qg,ql_dbz,&
                        qi_qr,qi_qsnow,qi_qg,qi_dbz,&
                        qr_qsnow,qr_qg,qr_dbz,&
                        qsnow_qg,qsnow_dbz,qg_dbz
    integer(i_kind)  :: vor_ps,div_ps,t_ps,ps_qs,ps_w,ps_ql,ps_qi,ps_qr,ps_qsnow, ps_qg,ps_dbz


    vor_div=1
    vor_t=2
    vor_qs=3
    vor_w=4
    vor_ql=5
    vor_qi=6
    vor_qr=7
    vor_qsnow=8
    vor_qg=9
    vor_dbz=10
    div_t=11
    div_qs=12
    div_w=13
    div_ql=14
    div_qi=15
    div_qr=16
    div_qsnow=17
    div_qg=18
    div_dbz=19
    t_qs=20
    t_w=21
    t_ql=22
    t_qi=23
    t_qr=24
    t_qsnow=25
    t_qg=26
    t_dbz=27
    qs_w=28
    qs_ql=29
    qs_qi=30
    qs_qr=31
    qs_qsnow=32
    qs_qg=33
    qs_dbz=34
    w_ql=35
    w_qi=36
    w_qr=37
    w_qsnow=38
    w_qg=39
    w_dbz=40
    ql_qi=41
    ql_qr=42
    ql_qsnow=43
    ql_qg=44
    ql_dbz=45
    qi_qr=46
    qi_qsnow=47
    qi_qg=48
    qi_dbz=49
    qr_qsnow=50
    qr_qg=51
    qr_dbz=52
    qsnow_qg=53
    qsnow_dbz=54
    qg_dbz=55

    vor_ps=1
    div_ps=2
    t_ps=3
    ps_qs=4
    ps_w=5
    ps_ql=6
    ps_qi=7
    ps_qr=8
    ps_qsnow=9
    ps_qg=10
    ps_dbz=11

       do k=1,nsig
          do m=1,nsig
            do j=1,lon2
              do i=1,lat2
                dbz(i,j,k) = dbz(i,j,k) + evik3(qg_dbz,i,j,k,m)*qg(i,j,m)+ &
                             evik3(qsnow_dbz,i,j,k,m)*qs(i,j,m) + &
                             evik3(qr_dbz,i,j,k,m)*qr(i,j,m) + &
                             evik3(qi_dbz,i,j,k,m)*qi(i,j,m) + &
                             evik3(ql_dbz,i,j,k,m)*ql(i,j,m) + &
                             evik3(w_dbz,i,j,k,m)*w(i,j,m)   + &
                             evik3(t_dbz,i,j,k,m)*t(i,j,m)   + &
                             evik2(ps_dbz,i,j,k)*ps(i,j)   + &
                             evik3(qs_dbz,i,j,k,m)*q(i,j,m) + &
                             evik3(div_dbz,i,j,k,m)*div(i,j,m) + &
                             evik3(vor_dbz,i,j,k,m)*vor(i,j,m)
              end do
            end do
          end do
       end do
       do k=1,nsig
          do m=1,nsig
            do j=1,lon2
              do i=1,lat2
                qg(i,j,k)  = qg(i,j,k) + &
                             evik3(qsnow_qg,i,j,k,m)*qs(i,j,m) + &
                             evik3(qr_qg,i,j,k,m)*qr(i,j,m) + &
                             evik3(qi_qg,i,j,k,m)*qi(i,j,m) + &
                             evik3(ql_qg,i,j,k,m)*ql(i,j,m) + &
                             evik3(w_qg,i,j,k,m)*w(i,j,m)   + &
                             evik3(t_qg,i,j,k,m)*t(i,j,m)   + &
                             evik2(ps_qg,i,j,k)*ps(i,j)   + &
                             evik3(qs_qg,i,j,k,m)*q(i,j,m) + &
                             evik3(div_qg,i,j,k,m)*div(i,j,m) + &
                             evik3(vor_qg,i,j,k,m)*vor(i,j,m)
              end do
            end do
          end do
       end do
       do k=1,nsig
          do m=1,nsig
            do j=1,lon2
              do i=1,lat2
                qs(i,j,k)  = qs(i,j,k) + &
                             evik3(qr_qsnow,i,j,k,m)*qr(i,j,m) + &
                             evik3(qi_qsnow,i,j,k,m)*qi(i,j,m) + &
                             evik3(ql_qsnow,i,j,k,m)*ql(i,j,m) + &
                             evik3(w_qsnow,i,j,k,m)*w(i,j,m) + &
                             evik3(t_qsnow,i,j,k,m)*t(i,j,m) + &
                             evik2(ps_qsnow,i,j,k)*ps(i,j) + &
                             evik3(qs_qsnow,i,j,k,m)*q(i,j,m)+&
                             evik3(div_qsnow,i,j,k,m)*div(i,j,m) + &
                             evik3(vor_qsnow,i,j,k,m)*vor(i,j,m)
              end do
            end do
          end do
       end do
       do k=1,nsig
          do m=1,nsig
            do j=1,lon2
              do i=1,lat2
                qr(i,j,k)  = qr(i,j,k) + &
                             evik3(qi_qr,i,j,k,m)*qi(i,j,m) + &
                             evik3(ql_qr,i,j,k,m)*ql(i,j,m) + &
                             evik3(w_qr,i,j,k,m)*w(i,j,m)   + &
                             evik3(t_qr,i,j,k,m)*t(i,j,m)   + &
                             evik2(ps_qr,i,j,k)*ps(i,j) + &
                             evik3(qs_qr,i,j,k,m)*q(i,j,m) + &
                             evik3(div_qr,i,j,k,m)*div(i,j,m) + &
                             evik3(vor_qr,i,j,k,m)*vor(i,j,m)
              end do
            end do
          end do
       end do
       do k=1,nsig
          do m=1,nsig
            do j=1,lon2
              do i=1,lat2
                qi(i,j,k)  = qi(i,j,k) + &
                             evik3(ql_qi,i,j,k,m)*ql(i,j,m) + &
                             evik3(w_qi,i,j,k,m)*w(i,j,m) + &
                             evik3(t_qi,i,j,k,m)*t(i,j,m) + &
                             evik2(ps_qi,i,j,k)*ps(i,j) + &
                             evik3(div_qi,i,j,k,m)*div(i,j,m)   + &
                             evik3(vor_qi,i,j,k,m)*vor(i,j,m)   + &
                             evik3(qs_qi,i,j,k,m)*q(i,j,m)
              end do
            end do
          end do
       end do
       do k=1,nsig
          do m=1,nsig
            do j=1,lon2
              do i=1,lat2
                ql(i,j,k)  = ql(i,j,k) + &
                             evik3(w_ql,i,j,k,m)*w(i,j,m)   + &
                             evik3(t_ql,i,j,k,m)*t(i,j,m)   + &
                             evik3(qs_ql,i,j,k,m)*q(i,j,m) + &
                             evik2(ps_ql,i,j,k)*ps(i,j) + &
                             evik3(div_ql,i,j,k,m)*div(i,j,m)+ &
                             evik3(vor_ql,i,j,k,m)*vor(i,j,m)
              end do
            end do
          end do
       end do
       do k=1,nsig
          do m=1,nsig
            do j=1,lon2
              do i=1,lat2
                w(i,j,k)   = w(i,j,k) + &
                             evik3(t_w,i,j,k,m)*t(i,j,m)   + &
                             evik3(qs_w,i,j,k,m)*q(i,j,m) + &
                             evik2(ps_w,i,j,k)*ps(i,j) + &
                             evik3(div_w,i,j,k,m)*div(i,j,m)   + &
                             evik3(vor_w,i,j,k,m)*vor(i,j,m)
              end do
            end do
          end do
       end do
       do k=1,nsig
          do m=1,nsig
            do j=1,lon2
              do i=1,lat2
                q(i,j,k)   = q(i,j,k) + &
                             evik3(div_qs,i,j,k,m)*div(i,j,m) + &
                             evik3(vor_qs,i,j,k,m)*vor(i,j,m) + &
                             evik3(t_qs,i,j,k,m)*t(i,j,m) + &
                             evik2(ps_qs,i,j,k)*ps(i,j)
              end do
            end do
          end do
       end do
       do m=1,nsig
          do j=1,lon2
            do i=1,lat2
                ps(i,j)    = ps(i,j) + &
                             evik2(div_ps,i,j,m)* div(i,j,m) + &
                             evik2(vor_ps,i,j,m)* vor(i,j,m) + &
                             evik2(t_ps,i,j,m)* t(i,j,m)
            end do
          end do
       end do
       do k=1,nsig
          do m=1,nsig
            do j=1,lon2
              do i=1,lat2
                t(i,j,k)   = t(i,j,k) + &
                             evik3(vor_t,i,j,k,m)*vor(i,j,m) + &
                             evik3(div_t,i,j,k,m)*div(i,j,m)
              end do
            end do
          end do
       end do
       do k=1,nsig
          do m=1,nsig
            do j=1,lon2
              do i=1,lat2
                div(i,j,k) = div(i,j,k) + &
                             evik3(vor_div,i,j,k,m)*vor(i,j,m)
              end do
            end do
          end do
       end do

    return

  end subroutine balance_extra

  subroutine tbalance_extra(vor,div,t,ps,q,w,qr,qs,qg,ql,qi,dbz)
    use constants, only: one,half
    use gsi_4dvar, only: lsqrtb
    use gridmod, only: regional,lat2,nsig,lon2
    implicit none

!   Declare passed variables
    real(r_kind),dimension(lat2,lon2),intent(inout)      :: ps
    real(r_kind),dimension(lat2,lon2,nsig),intent(inout) :: vor,div,ql,qi
    real(r_kind),dimension(lat2,lon2,nsig),intent(inout) :: t,q,w,qr,qs,qg,dbz

!   Declare local variables
    integer(i_kind) i,j,k,l,m

    integer(i_kind)  :: vor_div, vor_qs, vor_t, vor_w, vor_ql,vor_qi,vor_qr,vor_qsnow,vor_qg, &
                        vor_dbz,&
                        div_qs, div_t, div_w, div_ql, div_qi, div_qr,div_qsnow,div_qg,div_dbz,&
                        t_qs,t_w,t_ql,t_qi,t_qr,t_qsnow,t_qg,t_dbz,&
                        qs_w,qs_ql,qs_qi,qs_qr,qs_qsnow,qs_qg, qs_dbz,&
                        w_ql,w_qi,w_qr,w_qsnow,w_qg,w_dbz, &
                        ql_qi,ql_qr,ql_qsnow,ql_qg,ql_dbz,&
                        qi_qr,qi_qsnow,qi_qg,qi_dbz,&
                        qr_qsnow,qr_qg,qr_dbz,&
                        qsnow_qg,qsnow_dbz,qg_dbz
    integer(i_kind)  :: vor_ps,div_ps,t_ps,ps_qs,ps_w,ps_ql,ps_qi,ps_qr,ps_qsnow, ps_qg,ps_dbz

    vor_div=1
    vor_t=2
    vor_qs=3
    vor_w=4
    vor_ql=5
    vor_qi=6
    vor_qr=7
    vor_qsnow=8
    vor_qg=9
    vor_dbz=10
    div_t=11
    div_qs=12
    div_w=13
    div_ql=14
    div_qi=15
    div_qr=16
    div_qsnow=17
    div_qg=18
    div_dbz=19
    t_qs=20
    t_w=21
    t_ql=22
    t_qi=23
    t_qr=24
    t_qsnow=25
    t_qg=26
    t_dbz=27
    qs_w=28
    qs_ql=29
    qs_qi=30
    qs_qr=31
    qs_qsnow=32
    qs_qg=33
    qs_dbz=34
    w_ql=35
    w_qi=36
    w_qr=37
    w_qsnow=38
    w_qg=39
    w_dbz=40
    ql_qi=41
    ql_qr=42
    ql_qsnow=43
    ql_qg=44
    ql_dbz=45
    qi_qr=46
    qi_qsnow=47
    qi_qg=48
    qi_dbz=49
    qr_qsnow=50
    qr_qg=51
    qr_dbz=52
    qsnow_qg=53
    qsnow_dbz=54
    qg_dbz=55

    vor_ps=1
    div_ps=2
    t_ps=3
    ps_qs=4
    ps_w=5
    ps_ql=6
    ps_qi=7
    ps_qr=8
    ps_qsnow=9
    ps_qg=10
    ps_dbz=11

       do m=1,nsig
          do k=1,nsig
            do j=1,lon2
              do i=1,lat2
                vor(i,j,m)   = vor(i,j,m) + &
                               evik3(vor_div,i,j,k,m)*div(i,j,k) + &
                               evik3(vor_qs,i,j,k,m)*q(i,j,k) + &
                               evik2(vor_ps,i,j,m)*ps(i,j) + &
                               evik3(vor_t,i,j,k,m)*t(i,j,k) +&
                               evik3(vor_w,i,j,k,m)*w(i,j,k) +&
                               evik3(vor_ql,i,j,k,m)*ql(i,j,k)+&
                               evik3(vor_qi,i,j,k,m)*qi(i,j,k)+&
                               evik3(vor_qr,i,j,k,m)*qr(i,j,k)+&
                               evik3(vor_qsnow,i,j,k,m)*qs(i,j,k)+&
                               evik3(vor_qg,i,j,k,m)*qg(i,j,k)+&
                               evik3(vor_dbz,i,j,k,m)*dbz(i,j,k)
              end do
            end do
          end do
       end do
       do m=1,nsig
          do k=1,nsig
            do j=1,lon2
              do i=1,lat2
                div(i,j,m)   = div(i,j,m) + &
                               evik3(div_qs,i,j,k,m)*q(i,j,k) + &
                               evik2(div_ps,i,j,m)*ps(i,j) + &
                               evik3(div_t,i,j,k,m)*t(i,j,k)  + &
                               evik3(div_w,i,j,k,m)*w(i,j,k)  + &
                               evik3(div_ql,i,j,k,m)*ql(i,j,k)+ &
                               evik3(div_qi,i,j,k,m)*qi(i,j,k)+ &
                               evik3(div_qr,i,j,k,m)*qr(i,j,k)+ &
                               evik3(div_qsnow,i,j,k,m)*qs(i,j,k)+ &
                               evik3(div_qg,i,j,k,m)*qg(i,j,k)+ &
                               evik3(div_dbz,i,j,k,m)*dbz(i,j,k)
              end do
            end do
          end do
       end do
       do m=1,nsig
          do k=1,nsig
            do j=1,lon2
              do i=1,lat2
                t(i,j,m)     = t(i,j,m) + &
                               evik3(t_qs,i,j,k,m)*q(i,j,k)   + &
                               evik3(t_w,i,j,k,m)*w(i,j,k)   + &
                               evik3(t_ql,i,j,k,m)*ql(i,j,k)   + &
                               evik3(t_qi,i,j,k,m)*qi(i,j,k)   + &
                               evik3(t_qr,i,j,k,m)*qr(i,j,k)   + &
                               evik3(t_qsnow,i,j,k,m)*qs(i,j,k)   + &
                               evik3(t_qg,i,j,k,m)*qg(i,j,k)   + &
                               evik3(t_dbz,i,j,k,m)*dbz(i,j,k) + &
                               evik2(t_ps,i,j,m)*ps(i,j)
              end do
            end do
          end do
       end do

          do k=1,nsig
            do j=1,lon2
              do i=1,lat2
                ps(i,j)      = ps(i,j) + &
                               evik2(ps_qs,i,j,k)*q(i,j,k)+&
                               evik2(ps_w,i,j,k)*w(i,j,k)   + &
                               evik2(ps_ql,i,j,k)*ql(i,j,k)   + &
                               evik2(ps_qi,i,j,k)*qi(i,j,k)   + &
                               evik2(ps_qr,i,j,k)*qr(i,j,k)   + &
                               evik2(ps_qsnow,i,j,k)*qs(i,j,k)   + &
                               evik2(ps_qg,i,j,k)*qg(i,j,k)   + &
                               evik2(ps_dbz,i,j,k)*dbz(i,j,k)
              end do
            end do
          end do

       do m=1,nsig
          do k=1,nsig
            do j=1,lon2
              do i=1,lat2
                q(i,j,m)     = q(i,j,m) + &
                               evik3(qs_w,i,j,k,m)*w(i,j,k)   + &
                               evik3(qs_ql,i,j,k,m)*ql(i,j,k)   + &
                               evik3(qs_qi,i,j,k,m)*qi(i,j,k)   + &
                               evik3(qs_qr,i,j,k,m)*qr(i,j,k)   + &
                               evik3(qs_qsnow,i,j,k,m)*qs(i,j,k)   + &
                               evik3(qs_qg,i,j,k,m)*qg(i,j,k)   + &
                               evik3(qs_dbz,i,j,k,m)*dbz(i,j,k)
              end do
            end do
          end do
       end do
       do m=1,nsig
          do k=1,nsig
            do j=1,lon2
              do i=1,lat2

                w(i,j,m)     = w(i,j,m) + &
                               evik3(w_ql,i,j,k,m)*ql(i,j,k)   + &
                               evik3(w_qi,i,j,k,m)*qi(i,j,k)   + &
                               evik3(w_qr,i,j,k,m)*qr(i,j,k)   + &
                               evik3(w_qsnow,i,j,k,m)*qs(i,j,k)   + &
                               evik3(w_qg,i,j,k,m)*qg(i,j,k)   + &
                               evik3(w_dbz,i,j,k,m)*dbz(i,j,k)

              end do
            end do
          end do
       end do
       do m=1,nsig
          do k=1,nsig
            do j=1,lon2
              do i=1,lat2
                ql(i,j,m)    = ql(i,j,m) + &
                               evik3(ql_qi,i,j,k,m)*qi(i,j,k) + &
                               evik3(ql_qr,i,j,k,m)*qr(i,j,k) + &
                               evik3(ql_qsnow,i,j,k,m)*qs(i,j,k) + &
                               evik3(ql_qg,i,j,k,m)*qg(i,j,k) + &
                               evik3(ql_dbz,i,j,k,m)*dbz(i,j,k)
              end do
            end do
          end do
       end do
       do m=1,nsig
          do k=1,nsig
            do j=1,lon2
              do i=1,lat2
                qi(i,j,m)    = qi(i,j,m) + &
                               evik3(qi_qr,i,j,k,m)*qr(i,j,k) + &
                               evik3(qi_qsnow,i,j,k,m)*qs(i,j,k) + &
                               evik3(qi_qg,i,j,k,m)*qg(i,j,k) + &
                               evik3(qi_dbz,i,j,k,m)*dbz(i,j,k)
              end do
            end do
          end do
       end do
       do m=1,nsig
          do k=1,nsig
            do j=1,lon2
              do i=1,lat2
                qr(i,j,m)    = qr(i,j,m) + &
                               evik3(qr_qsnow,i,j,k,m)*qs(i,j,k) + &
                               evik3(qr_qg,i,j,k,m)*qg(i,j,k) + &
                               evik3(qr_dbz,i,j,k,m)*dbz(i,j,k)
              end do
            end do
          end do
       end do
       do m=1,nsig
          do k=1,nsig
            do j=1,lon2
              do i=1,lat2
                qs(i,j,m)    = qs(i,j,m) + &
                               evik3(qsnow_qg,i,j,k,m)*qg(i,j,k) + &
                               evik3(qsnow_dbz,i,j,k,m)*dbz(i,j,k)
              end do
            end do
          end do
       end do
       do m=1,nsig
          do k=1,nsig
            do j=1,lon2
              do i=1,lat2
                qg(i,j,m)    = qg(i,j,m) + &
                               evik3(qg_dbz,i,j,k,m)*dbz(i,j,k)
              end do
            end do
          end do
       end do

    return

  end subroutine tbalance_extra

  subroutine locatelat_reg(mype)      
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    locatelat_reg   calc interp coeffs for background stats
!   prgmmr: wu               org: np22                date: 2004-03-15
!
! abstract: calculates interpolation indexes and weights between 
!           the background error statistics and the analysis grids                        
!
! program history log:
!   2004-03-15  wu       
!   2004-06-14  wu, documentation and clean up       
!   2004-07-28  treadon - simplify subroutine call list
!   2005-03-28  wu - replace mlath with mlat
!   2005-04-22  treadon - change berror file to 4-byte reals
!   2005-06-06  wu - setup f1 for balance projection (st->t) when fstat=.true.
!
!   input argument list:
!     mype     - mpi task id
!
!   output argument list
!
! remarks: see modules used
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
    use kinds, only: r_single
    use gridmod, only: nlon,nlat,lat2,lon2,istart,jstart,region_lat
    use constants, only: deg2rad,one
    implicit none
    
!   Declare passed variables
    integer(i_kind),intent(in   ) :: mype

!   Declare local variables
    integer(i_kind) i,j,msig,mlat,lunin,m,m1,mm1,jl,il
    real(r_kind) fmid
    real(r_kind),allocatable,dimension(:):: clat_avn
    real(r_single),allocatable,dimension(:):: clat_avn4


!   Read in dim of stats file
    lunin=22
    open(lunin,file='berror_stats',form='unformatted',convert="little_endian")
    rewind lunin
    read(lunin)msig,mlat
    

!   Allocate and read in lat array in stats file
    allocate( clat_avn(mlat), clat_avn4(mlat) )
    read(lunin)clat_avn4
    close(lunin)
    do i=1,mlat
       clat_avn(i)=clat_avn4(i)*deg2rad
    end do
    deallocate(clat_avn4)
    

!   Decide and output rllat,rllat1,llmax,llmin (through module berror )
!   rllat: location of analysis grid in stats grid unit (whole domain)
!   llmax,llmin: max,min stats grid needed in analysis domain
!   rllat1: location of analysis grid in stats grid unit (MPP local domain)

    llmax=-999
    llmin=999
    do j=1,nlon 
       do i=1,nlat   
          if(region_lat(i,j)>=clat_avn(mlat))then
             rllat(i,j)=float(mlat)
             llmax=max0(mlat,llmax)
             llmin=min0(mlat,llmin)
          else if(region_lat(i,j)<clat_avn(1))then
             rllat(i,j)=one
             llmax=max0(1,llmax)
             llmin=min0(1,llmin)
          else
             do m=1,mlat-1
                m1=m+1
                if((region_lat(i,j)>=clat_avn(m)).and.  &
                   (region_lat(i,j)<clat_avn(m1)))then
                   rllat(i,j)=float(m)
                   llmax=max0(m,llmax)
                   llmin=min0(m,llmin)
                   exit
                end if
             end do
             rllat(i,j)=rllat(i,j)+(region_lat(i,j)-clat_avn(m))/(clat_avn(m1)-clat_avn(m))
          endif
       end do
    end do
    llmax=min0(mlat,llmax+1)
    llmin=max0(1,llmin-1)
    
    deallocate(clat_avn)
    
    mm1=mype+1
    do j=1,lon2            
       jl=j+jstart(mm1)-2
       jl=min0(max0(1,jl),nlon)
       do i=1,lat2            
          il=i+istart(mm1)-2
          il=min0(max0(1,il),nlat)
          rllat1(i,j)=rllat(il,jl)
       enddo
    enddo
    if(fstat)then
       fmid=one/sin(region_lat(nlat/2,nlon/2))
       do j=1,lon2
          jl=j+jstart(mm1)-2
          jl=min0(max0(1,jl),nlon)
          do i=1,lat2
             il=i+istart(mm1)-2
             il=min0(max0(1,il),nlat)
             f1(i,j)=sin(region_lat(il,jl))*fmid
          enddo
       enddo
    endif
    
    return
end subroutine locatelat_reg
  
subroutine strong_bk(st,vp,p,t,uvflag)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    strong_bk   apply strong balance constraint
!   prgmmr: derber           org: np23                date: 2003-12-18
!
! abstract: apply strong balance constraint
!
!
! program history log:
!   2008-09-19  derber,j.
!   2008-12-29  todling   - redefine interface
!   2009-04-21  derber - modify interface with calctends_no
!   2012-02-08  kleist  - add uvflag input parameter, passed in call to calctends_no_tl 
!                            and strong_bal_correction
!
!   input argument list:
!     st       - input control vector, stream function
!     vp       - input control vector, velocity potential
!     p        - input control vector, surface pressure
!     t        - input control vector, temperature
!
!   output argument list:
!     st       - output control vector, stream function
!     vp       - output control vector, velocity potential
!     p        - output control vector, surface pressure
!     t        - output control vector, temperature
!
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use mpimod, only: mype
  use gridmod, only: latlon1n,latlon11
  use mod_vtrans,only: nvmodes_keep
  use mod_strong,only: nstrong
  implicit none

! Declare passed variables
  real(r_kind),dimension(latlon1n),intent(inout) :: st,vp
  real(r_kind),dimension(latlon11),intent(inout) :: p
  real(r_kind),dimension(latlon1n),intent(inout) :: t
  logical, intent(in):: uvflag

  logical:: fullfield
  integer(i_kind) istrong
  real(r_kind),dimension(latlon1n)::u_t,v_t,t_t
  real(r_kind),dimension(latlon11):: ps_t

!******************************************************************************  
  if(nvmodes_keep <= 0 .or. nstrong <= 0) return

! compute derivatives

  fullfield=.false.
  do istrong=1,nstrong
 
     call calctends_no_tl(st,vp,t,p,mype,u_t,v_t,t_t,ps_t,uvflag)

     call strong_bal_correction(u_t,v_t,t_t, &
          ps_t,mype,st,vp,t,p,.false.,fullfield,.true.,uvflag)

  end do

  return
end subroutine strong_bk

subroutine strong_bk_ad(st,vp,p,t,uvflag)
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:    strong_bk_ad   apply adjoint of strong balance constraint
!   prgmmr: derber           org: np23                date: 2003-12-18
!
! abstract: apply adjoint of strong balance constraint
!
!
! program history log:
!   2008-09-19  derber,j.
!   2008-12-29  todling   - redefine interface
!   2009-04-21  derber - modify interface with calctends_no
!   2012-02-08  kleist  - add uvflag input parameter, passed in call to calctends_no_ad 
!                            and strong_bal_correction_ad
!
!   input argument list:
!     st       - input control vector, stream function
!     vp       - input control vector, velocity potential
!     p        - input control vector, surface pressure
!     t        - input control vector, temperature
!
!   output argument list:
!     st       - output control vector, stream function
!     vp       - output control vector, velocity potential
!     p        - output control vector, surface pressure
!     t        - output control vector, temperature
!
!
! attributes:
!   language: f90
!   machine:  ibm RS/6000 SP
!
!$$$
  use mpimod, only: mype
  use constants, only: zero
  use gridmod, only: latlon1n,latlon11
  use mod_vtrans,only: nvmodes_keep
  use mod_strong,only: nstrong
  implicit none
  
! Declare passed variables  
  real(r_kind),dimension(latlon1n),intent(inout) :: st,vp
  real(r_kind),dimension(latlon11),intent(inout) :: p
  real(r_kind),dimension(latlon1n),intent(inout) :: t
  logical,intent(in):: uvflag

! Declare local variables  	
  integer(i_kind) i
  real(r_kind),dimension(latlon1n):: u_t,v_t,t_t
  real(r_kind),dimension(latlon11):: ps_t
  integer(i_kind) istrong

!******************************************************************************

  if(nvmodes_keep <= 0 .or. nstrong <= 0) return
     
  do istrong=1,nstrong
! Zero gradient arrays
     do i=1,latlon1n
        u_t(i)=zero
        v_t(i)=zero
        t_t(i)=zero
     end do
     do i=1,latlon11
        ps_t(i)=zero
     end do

     call strong_bal_correction_ad(u_t,v_t,t_t,ps_t,mype,st,vp,t,p,uvflag)

     call calctends_no_ad(st,vp,t,p,mype,u_t,v_t,t_t,ps_t,uvflag)  
!
  end do

  return
end subroutine strong_bk_ad

end module balmod
