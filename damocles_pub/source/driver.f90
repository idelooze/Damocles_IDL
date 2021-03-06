MODULE driver

    USE input
    USE initialise

    USE vector_functions
    USE init_packet
    USE model_comparison

    IMPLICIT NONE

    INTEGER,EXTERNAL ::  omp_get_num_threads, omp_get_thread_num
    INTEGER ::  lgabs,lgactive,idP_thread
    INTEGER ::  celliD,iG,iG_axis(3),freqid,los


    REAL    ::  nu_p,theta,w,w_abs
    REAL    ::  dir_cart(3),pos_cart(3)
    INTEGER ::  scatno
    INTEGER ::  NP_clump

contains


    SUBROUTINE run_code(param_struct,chi2)
        implicit none
        
        REAL    ::  chi2
        REAL    ::  param_struct(pp_no)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        !NOTES

        !system refers to the coordinate system in which the coordinates are specified - system SN and system PT

        !system SN is centered on the supernova with the z-axis orientated along the line of sight to the observer

        !system PT is centered on the scattering/emitting particle with the z-axis orientated along the direction
        !of motion of the particle (i.e. radially wrt system SN) and the x-axis orientated in line with the phi direction wrt system SN

        !RF = SCAT_RF_PT frame (i.e. the frame of the observer)

        !CMF = comoving frame (i.e. the frame in which the emitting/scattering particle is at SCAT_RF_PT)

        !NOTE THAT SYSTEM SN IS FIXED AND DOES NOT CHANGE WHEREAS SYSTEM PT VARIES WITH THE PARTICLE IN CONSIDERATION


        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!INITIALIZE PHOTON EMISSION!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


        !READ INPUTS AND CONSTRUCT GRID
        call read_input(param_struct)
        PRINT*, 'input read, calculating opacities...'

        !lambda_0 is active initial wavelength
        lambda_0=lambda1_0
        
        w_abs=0
        DO iDoublet=1,2

            IF ((.not. lgDoublet) .and. (iDoublet==2))  THEN
                EXIT
            ELSE
                IF (iDoublet==2) THEN
                    !active wavelength is now second element of doublet
                    lambda_0=lambda2_0
                    nu_0=c*10**9/lambda_0
                    PRINT*,'NUCHECK',nu_0
                END IF


                IF (iDoublet==1) THEN
                    !Construct grid
                    call set_grid_globals(param_struct)
                    PRINT*, 'Opacities calculated, constructing grid and frequency array...'

                    PRINT*, 'grid constructed.'
                    !OPEN ENERGY OUTPUT FILE
                    !OPEN(13,file=trim(filename))
                    OPEN(15,file='output/output.out')

                END IF

                PRINT*,"iDoublet",iDoublet
                PRINT*,"wavelength",lambda_0

                !SET COUNTERS EQUAL TO 0
                idP=0
                IF (iDoublet==1) THEN
                    n=0
                    n_inactive=0
                    nabs=0
                END IF

                !!freqid(:,:)=1
                !w_abs=0

                tot=0
                !!los(:,:)=0.

                !GENERATE RANDOM SEED AND MATRIX
                PRINT*, 'generating random seed...'
                CALL init_random_seed
                !PRINT*, 'generating random number matrix...'


                PRINT*, 'starting iteration...'
                !CALCULATE NO PACKETS IN SHELL,
                !POSITION OF PACKETS AND DOPPLER SHIFTED FREQUENCY.
                !TRACE PHOTONS THROUGH GRID.
                !!!!!!!!!!!!!!!!!!!!!!!!

                IF (iDoublet==1) THEN
                    shell_width=(R_max_gas-R_min_gas)/n_shells					!Calculate width of shells
                    PRINT*,'****************SHELL WIDTH****************',shell_width
                    !const=n_packets*(0*q-1)/(R_min**(1-0*q)-R_max**(1-0*q))
                    !const=n_packets*(2*q-1)/(R_min**(1-2*q)-R_max**(1-2*q))

                    !scale factor to work out number of packets in each shell

                    IF ((b_gas*q_gas)==3) THEN
                        const=n_packets/(LOG(R_max_gas/R_min_gas))
                    ELSE
                        const=n_packets*(b_gas*q_gas-3)/(R_min_gas**(3-b_gas*q_gas)-R_max_gas**(3-b_gas*q_gas))
                    END IF

                    PRINT*,'CONST',const
                    RSh(1,1)=R_min_gas
                    RSh(1,2)=R_min_gas+shell_width
                END IF

                IF (iDoublet==1) THEN
                    NP_BIN=0
                    w_abs=0
                    nabs=0
                END IF
                idP=0
                
                i=0
                IF (clumpgas==1) THEN
                NP(:,1)=0
                   DO iSh=1,totcells
                        IF (mgrid(iSh)%cellStatus==1) THEN
                           i=i+1
                           PRINT*,'clump number',i,'of',ncl
                            
                            
                            NP(iSh,1)=n_packets/ncl
                            n=n+NP(iSh,1)
                            
                            celliD=iSh
                            call run_packets(celliD)
                        END IF

                    END DO

                ELSE
                DO iSh=1,n_shells
                   
                !divide the SN up into radial shells
                     !NP(iSh,1)=NINT(const*(RSh(iSh,1)**(1-0*q)-RSh(iSh,2)**(1-0*q))/(0*q-1))
                     !NP(iSh,1)=NINT(const*(RSh(iSh,1)**(1-2*q)-RSh(iSh,2)**(1-2*q))/(2*q-1))						!calculate number of packets to be released in shell i
                   PRINT*,'shell no',iSh,'of',n_shells
                    IF (iDoublet==1) THEN
                        IF ((b_gas*q_gas)==3) THEN
                            NP(iSh,1)=NINT(const*LOG(RSh(iSh,2)/RSh(iSh,1)))
                        ELSE
                            NP(iSh,1)=NINT(const*(RSh(iSh,1)**(3-b_gas*q_gas)-RSh(iSh,2)**(3-b_gas*q_gas))/(b_gas*q_gas-3))
                        END IF
                        
                    END IF
                    n=n+NP(iSh,1)
                    iG=0 !to be calculated by emit_photon routine in run_packets (see below)
                   
                    call run_packets(iG)

                    RSh(iSh+1,1:2)=(/ RSh(iSh,2),RSh(iSh,2)+shell_width /)  								!calculate upper and lower radius bound for each shell

                END DO
                END IF
            END IF
        END DO
        !!!!!!!!!!!!!!!!!!!!!!!!

        IF (lgDoublet) THEN
           PRINT*,L_tot,n,n_inactive,2.0*n-n_inactive
            E_0=L_tot/real(2.0*n-n_inactive)												!Energy of a single packet in W/um (note uses actual number of active photons)
        
         ELSE
            E_0=L_tot/real(n-n_inactive)
        END IF

        PRINT*,E_0,'E0'

        PRINT*,''
        PRINT*,'**********************'
        PRINT*,'All percentages out of total number of active packets:'
        PRINT*,''
        PRINT*,'TOTAL NUMBER OF PACKETS',n
        PRINT*,'NUMBER OF ACTIVE(PROPAGATED) PACKETS',n-n_inactive
        !WRITE OUT ENERGY FILE - wavelength, velocity, energy (W/um)
        DO inu=1,n_bins-1
                lambda_bin=(c*10**9)*(0.5/nu_bin(inu,1)+0.5/nu_bin(inu+1,1))
                IF (.not. lgDoublet) THEN
                    vel_bin=(c*1e-3*(lambda_bin**2-lambda_0**2)/(lambda_0**2+lambda_bin**2))
                    !WRITE(13,*) lambda_bin,vel_bin,E_0*NP_BIN(inu)
                    WRITE(15,*) lambda_bin,vel_bin,E_0*NP_BIN(inu)    !duplicate file for plotting
                ELSE
                    !WRITE(13,*) lambda_bin,E_0*NP_BIN(inu)
                   
                   WRITE(15,*) lambda_bin,E_0*NP_BIN(inu)    !duplicate file for plotting
                END IF
        END DO

        PRINT*,'*******************'
        PRINT*,'absorbed weight',w_abs
        IF (lgDoublet) THEN
           PRINT*,'undepleted luminosity (in units e40 erg/s)',L_tot/(1-w_abs/real(n-n_inactive))
        ELSE
           PRINT*,'undepleted luminosity (in units e40 erg/s)',L_tot/(1-w_abs/real(n-n_inactive))
        END IF
        !CLOSE(13)
        CLOSE(15)
        !CLOSE(17)
        IF (.not. lgDoublet) THEN

        PRINT*,'NUMBER OF INACTIVE PACKETS',n_inactive
        PRINT*,'NUMBER OF ABSORBED PACKETS',nabs,real(nabs)*100/real(n-n_inactive),'%'
        PRINT*,'ABSORBED WEIGHT PERCENTAGE',w_abs*100/real(n-n_inactive),'%'
        PRINT*,''
        PRINT*,'TOTAL ENERGY',L_tot
        PRINT*,'ENERGY PER PACKET (ACTIVE ONLY)',E_0
        PRINT*,'TOTAL ENERGY ABSORBED',nabs*E_0
        PRINT*,''
        PRINT*,'FRACTION OF ESCAPED PACKETS IN LINE OF SIGHT',tot,real(tot)*100/real((n-n_inactive-nabs)),'%'
        PRINT*,''
        PRINT*,'DUST MASS',MD_tot
        PRINT*,'OUTPUT FILENAME:  ', trim(filename)
        PRINT*,''
        PRINT*,'FINISHED MODELLING!'
        PRINT*,''
        PRINT*,'Calculating chi...'
        PRINT*,''
        
     ELSE

        PRINT*,'DUST MASS',MD_tot
        PRINT*,nabs,n,n_inactive
        PRINT*,'percentage of absorbed packets',real(nabs*100.0)/real(n-n_inactive)
        PRINT*,'absorbed weight',w_abs*100/real(n-n_inactive)
     PRINT*,'FINISHED MODELLING!'   
     END IF


        call linear_interp(chi2)

        DEALLOCATE(mgrid)
        DEALLOCATE(nu_bin)
        DEALLOCATE(tmp)
        DEALLOCATE(grid)
        DEALLOCATE(np)
        DEALLOCATE(np_bin)
        DEALLOCATE(RSh)
        DEALLOCATE(dust)
    END SUBROUTINE run_code

    SUBROUTINE run_packets(celliD)
      INTEGER::celliD

!!!!!OPENMP HAS NOT BEEN UPDATED AFTER RECENT AMENDMENTS SO DO NOT EMPLOY WITHOUT THOROUGH CHECKING FIRST!!!!!!!!!!!
!$OMP PARALLEL DEFAULT(PRIVATE) SHARED(ff,q_gas,pp_no,L_ratio,iDoublet,tot,n_inactive,nabs,shell_width,width,NP_BIN,NP,iSh,RSh,R_min,R_max,R_min_gas,R_max_gas,idP,lgLoS,lgES,grid,ncells,nu_bin,v_max,v_max_gas,l,l_gas,nu_0,dummy,mgrid,dust,lgVelShift)

                    !PRINT*,'num of threads', omp_get_num_threads()

                    idP_thread=0

                    
                    !$OMP DO SCHEDULE(dynamic)
                    DO iP=1,NP(iSh,1)
                        !PRINT*,'thread number',omp_get_thread_num()
                       
                        call emit_photon(nu_p,dir_cart,pos_cart,iG_axis,lgactive,w,celliD)
                        
                        !PRINT*,'thread no',omp_get_thread_num()
                        IF (lgactive == 1) THEN
                            scatno=0
                            lgabs=0
                    
                            call propagate(nu_p,dir_cart,pos_cart*1e15,iG_axis,iG,lgabs,lgactive,w,scatno)
                    
                            theta=acos(pos_cart(3)/((pos_cart(1)**2+pos_cart(2)**2+pos_cart(3)**2)**0.5))
                            IF (lgabs == 1) THEN
                                !$OMP CRITICAL
                                nabs=nabs+1
                                IF (iDoublet==2) THEN
                                   w_abs=w_abs+w/L_ratio
                                ELSE
                                   w_abs=w_abs+w
                                END IF
                                !$OMP END CRITICAL
                            END IF


                            
                            ! IF PHOTON IN LINE OF SIGHT THEN CALCULATE WHICH FREQ BIN PACKET IN AND ADD 1 TO TOTAL IN FREQ BIN
                            IF (.not. lgLOS) THEN
                                IF (lgabs == 0) THEN
                                   
                                   los=1.
                                    tmp(:,1)=(nu_p-nu_bin(:,1))                         !Calculate distance to each freq point
                                    freq=MINLOC(tmp,1,tmp>0)                                !Find the smallest distance and thus nearest freq point
                                    freqid=freq(1)                              !Attach id of freq bin to photon id
                                    IF (freqid==0) THEN
                                        PRINT*,'photon outside frequency range',freqid,nu_p,w
                                        PRINT*,nu_min,nu_max
                                    ELSE
                                        IF (iDoublet==2) THEN
                                            w=w/L_ratio
                                        
                                        END IF
                                         !$OMP CRITICAL
                                        dummy=NP_BIN(freqid)+w                  !Add 1 to number of photons in that freq bin

                                        NP_BIN(freqid)=dummy

                                        tot=tot+1
                                         !$OMP END CRITICAL
                                    END IF
                                END IF
                            ELSE
                                IF ((theta<(pi/6)) .AND. (lgabs==0)) THEN                       !Only calculate freq bin for those in LoS
                                    !Packets which are not absorbed
                                    los=1.
                                    tmp(:,1)=(nu_p-nu_bin(:,1))                     !Calculate distance to each freq point
                                    freq=MINLOC(tmp,1,tmp>0)                            !Find the smallest distance and thus nearest freq point
                                    freqid=freq(1)                          !Attach id of freq bin to photon id
                                    IF (freqid==0) THEN
                                        PRINT*,'photon outside frequency range',freqid,nu_p,w
                                    ELSE
                                         !$OMP CRITICAL
                                        IF (lgDoublet) THEN
                                            IF (iDoublet==2) THEN
                                                w=w/L_ratio
                                        
                                            END IF
                                        END IF
                                        dummy=NP_BIN(freqid)+w                  !Add 1 to number of photons in that freq bin
                                        !PRINT*,w
                                        tot=tot+1
                                         !$OMP END CRITICAL
                                    END IF
                                END IF
                            END IF
                        END IF
!                        PRINT*,'threadno',omp_get_thread_num()
                     END DO
                    
                     !$OMP END DO

                     !$OMP CRITICAL
                    idP=idP+idP_thread
                     !$OMP END CRITICAL
                    
                     !$OMP END PARALLEL
                    
    END SUBROUTINE

END MODULE driver
