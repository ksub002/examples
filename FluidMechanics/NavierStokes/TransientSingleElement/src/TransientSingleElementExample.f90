!> \file
!> $Id: StokesFlowExample.f90 20 2009-04-08 20:22:52Z cpb $
!> \author Sebastian Krittian
!> \brief This is an example program to solve a Stokes equation using openCMISS calls.
!>
!> \section LICENSE
!>
!> Version: MPL 1.1/GPL 2.0/LGPL 2.1
!>
!> The contents of this file are subject to the Mozilla Public License
!> Version 1.1 (the "License"); you may not use this file except in
!> compliance with the License. You may obtain a copy of the License at
!> http://www.mozilla.org/MPL/
!>
!> Software distributed under the License is distributed on an "AS IS"
!> basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
!> License for the specific language governing rights and limitations
!> under the License.
!>
!> The Original Code is OpenCMISS
!>
!> The Initial Developer of the Original Code is University of Auckland,
!> Auckland, New Zealand and University of Oxford, Oxford, United
!> Kingdom. Portions created by the University of Auckland and University
!> of Oxford are Copyright (C) 2007 by the University of Auckland and
!> the University of Oxford. All Rights Reserved.
!>
!> Contributor(s):
!>
!> Alternatively, the contents of this file may be used under the terms of
!> either the GNU General Public License Version 2 or later (the "GPL"), or
!> the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
!> in which case the provisions of the GPL or the LGPL are applicable instead
!> of those above. If you wish to allow use of your version of this file only
!> under the terms of either the GPL or the LGPL, and not to allow others to
!> use your version of this file under the terms of the MPL, indicate your
!> decision by deleting the provisions above and replace them with the notice
!> and other provisions required by the GPL or the LGPL. If you do not delete
!> the provisions above, a recipient may use your version of this file under
!> the terms of any one of the MPL, the GPL or the LGPL.
!>

!> \example examples/StokesFlow/src/StokesFlowExample.f90
!! Example program to solve a Stokes equation using openCMISS calls.
!<

!> Main program

PROGRAM NavierStokesFlow

! OpenCMISS Modules

   USE BASE_ROUTINES
   USE BASIS_ROUTINES
   USE BOUNDARY_CONDITIONS_ROUTINES
   USE CMISS
   USE CMISS_MPI
   USE COMP_ENVIRONMENT
   USE CONSTANTS
   USE CONTROL_LOOP_ROUTINES
   USE COORDINATE_ROUTINES
   USE DOMAIN_MAPPINGS
   USE EQUATIONS_ROUTINES
   USE EQUATIONS_SET_CONSTANTS
   USE EQUATIONS_SET_ROUTINES
   USE FIELD_ROUTINES
   USE FIELD_IO_ROUTINES
   USE INPUT_OUTPUT
   USE ISO_VARYING_STRING
   USE KINDS
   USE MESH_ROUTINES
   USE MPI
   USE NODE_ROUTINES
   USE PROBLEM_CONSTANTS
   USE PROBLEM_ROUTINES
   USE REGION_ROUTINES
   USE SOLVER_ROUTINES
   USE TIMER
   USE TYPES
!!!!!
#ifdef WIN32
   USE IFQWIN
#endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! cmHeart input module
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  USE FLUID_MECHANICS_IO_ROUTINES

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  IMPLICIT NONE
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Program types
  TYPE(BOUNDARY_CONDITIONS_TYPE), POINTER :: BOUNDARY_CONDITIONS
  TYPE(COORDINATE_SYSTEM_TYPE), POINTER :: COORDINATE_SYSTEM
  TYPE(MESH_TYPE), POINTER :: MESH
  TYPE(DECOMPOSITION_TYPE), POINTER :: DECOMPOSITION
  TYPE(EQUATIONS_TYPE), POINTER :: EQUATIONS
  TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET
  TYPE(FIELD_TYPE), POINTER :: GEOMETRIC_FIELD, DEPENDENT_FIELD, MATERIALS_FIELD
  TYPE(PROBLEM_TYPE), POINTER :: PROBLEM
  TYPE(REGION_TYPE), POINTER :: REGION,WORLD_REGION
  TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP
  TYPE(SOLVER_TYPE), POINTER :: SOLVER,LINEAR_SOLVER,NONLINEAR_SOLVER
  TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS
  TYPE(BASIS_TYPE), POINTER :: BASIS_M,BASIS_V,BASIS_P
  TYPE(MESH_ELEMENTS_TYPE), POINTER :: MESH_ELEMENTS_M,MESH_ELEMENTS_P,MESH_ELEMENTS_V
  TYPE(NODES_TYPE), POINTER :: NODES

  !Program variables
  INTEGER(INTG) :: NUMBER_OF_DOMAINS
  INTEGER(INTG) :: MPI_IERROR
  INTEGER(INTG) :: EQUATIONS_SET_INDEX
  LOGICAL :: EXPORT_FIELD,IMPORT_FIELD
  TYPE(VARYING_STRING) :: FILE,METHOD
  REAL(SP) :: START_USER_TIME(1),STOP_USER_TIME(1),START_SYSTEM_TIME(1),STOP_SYSTEM_TIME(1)
  INTEGER(INTG) :: NUMBER_COMPUTATIONAL_NODES
  INTEGER(INTG) :: MY_COMPUTATIONAL_NODE_NUMBER
  INTEGER(INTG) :: ERR
  TYPE(VARYING_STRING) :: ERROR
  INTEGER(INTG) :: DIAG_LEVEL_LIST(5)
  CHARACTER(LEN=MAXSTRLEN) :: DIAG_ROUTINE_LIST(1),TIMING_ROUTINE_LIST(1)

   !User types
  TYPE(EXPORT_CONTAINER):: CM

   !User variables
  INTEGER:: DECOMPOSITION_USER_NUMBER
  INTEGER:: GEOMETRIC_FIELD_USER_NUMBER
  INTEGER:: DEPENDENT_FIELD_USER_NUMBER
  INTEGER:: DEPENDENT_FIELD_NUMBER_OF_VARIABLES
  INTEGER:: DEPENDENT_FIELD_NUMBER_OF_COMPONENTS
  INTEGER:: REGION_USER_NUMBER
  INTEGER:: BC_NUMBER_OF_INLET_NODES,BC_NUMBER_OF_WALL_NODES
  INTEGER:: COORDINATE_USER_NUMBER
  INTEGER:: MESH_NUMBER_OF_COMPONENTS
  INTEGER:: I,J,K,L,M,N
  INTEGER:: X_DIRECTION,Y_DIRECTION,Z_DIRECTION
  INTEGER, ALLOCATABLE, DIMENSION(:):: BC_INLET_NODES
  INTEGER, ALLOCATABLE, DIMENSION(:):: BC_WALL_NODES
  INTEGER, ALLOCATABLE, DIMENSION(:):: DOF_INDICES
  INTEGER, ALLOCATABLE, DIMENSION(:):: DOF_CONDITION
  REAL(DP),ALLOCATABLE, DIMENSION(:):: DOF_VALUES

  DOUBLE PRECISION:: DIVERGENCE_TOLERANCE, RELATIVE_TOLERANCE, ABSOLUTE_TOLERANCE
  INTEGER:: MAXIMUM_ITERATIONS,RESTART_VALUE

#ifdef WIN32
  !Quickwin type
  LOGICAL :: QUICKWIN_STATUS=.FALSE.
  TYPE(WINDOWCONFIG) :: QUICKWIN_WINDOW_CONFIG
#endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Program starts
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#ifdef WIN32
  !Initialise QuickWin
  QUICKWIN_WINDOW_CONFIG%TITLE="General Output" !Window title
  QUICKWIN_WINDOW_CONFIG%NUMTEXTROWS=-1 !Max possible number of rows
  QUICKWIN_WINDOW_CONFIG%MODE=QWIN$SCROLLDOWN
  !Set the window parameters
  QUICKWIN_STATUS=SETWINDOWCONFIG(QUICKWIN_WINDOW_CONFIG)
  !If attempt fails set with system estimated values
  IF(.NOT.QUICKWIN_STATUS) QUICKWIN_STATUS=SETWINDOWCONFIG(QUICKWIN_WINDOW_CONFIG)
#endif

 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Import cmHeart Information
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


  !Read node, element and basis information from cmheart input file
  !Receive CM container for adjusting OpenCMISS calls
  CALL FLUID_MECHANICS_IO_READ_CMHEART(CM,ERR,ERROR,*999)



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Intialise cmiss
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(WORLD_REGION)
  CALL CMISS_INITIALISE(WORLD_REGION,ERR,ERROR,*999)

!Set all diganostic levels on for testing
!  DIAG_LEVEL_LIST(1)=1
!  DIAG_LEVEL_LIST(2)=2
!  DIAG_LEVEL_LIST(3)=3
!  DIAG_LEVEL_LIST(4)=4
!  DIAG_LEVEL_LIST(5)=5
!  DIAG_ROUTINE_LIST(1)=""
!  CALL DIAGNOSTICS_SET_ON(ALL_DIAG_TYPE,DIAG_LEVEL_LIST,"StokesFlowExample",DIAG_ROUTINE_LIST,ERR,ERROR,*999)
!  CALL DIAGNOSTICS_SET_ON(ALL_DIAG_TYPE,DIAG_LEVEL_LIST,"",DIAG_ROUTINE_LIST,ERR,ERROR,*999)

  !TIMING_ROUTINE_LIST(1)=""
  !CALL TIMING_SET_ON(IN_TIMING_TYPE,.TRUE.,"",TIMING_ROUTINE_LIST,ERR,ERROR,*999)


  !Calculate the start times
  CALL CPU_TIMER(USER_CPU,START_USER_TIME,ERR,ERROR,*999)
  CALL CPU_TIMER(SYSTEM_CPU,START_SYSTEM_TIME,ERR,ERROR,*999)
  !Get the number of computational nodes
  NUMBER_COMPUTATIONAL_NODES=COMPUTATIONAL_NODES_NUMBER_GET(ERR,ERROR)
  IF(ERR/=0) GOTO 999
  !Get my computational node number
  MY_COMPUTATIONAL_NODE_NUMBER=COMPUTATIONAL_NODE_NUMBER_GET(ERR,ERROR)
  IF(ERR/=0) GOTO 999

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Start the creation of a new RC coordinate system
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(COORDINATE_SYSTEM)
  COORDINATE_USER_NUMBER=1
  CALL COORDINATE_SYSTEM_CREATE_START(COORDINATE_USER_NUMBER,COORDINATE_SYSTEM,ERR,ERROR,*999)
  !Set the coordinate system dimension to CM%D
  CALL COORDINATE_SYSTEM_DIMENSION_SET(COORDINATE_SYSTEM,CM%D,ERR,ERROR,*999)
  CALL COORDINATE_SYSTEM_CREATE_FINISH(COORDINATE_SYSTEM,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Start the creation of a region
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(REGION)

  REGION_USER_NUMBER=1

  CALL REGION_CREATE_START(REGION_USER_NUMBER,WORLD_REGION,REGION,ERR,ERROR,*999)
  !Set the regions coordinate system
  CALL REGION_COORDINATE_SYSTEM_SET(REGION,COORDINATE_SYSTEM,ERR,ERROR,*999)
  CALL REGION_CREATE_FINISH(REGION,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Start the creation of a basis for spatial, velocity and pressure field
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(BASIS_M)
  !Spatial basis BASIS_M (CM%ID_M)
  CALL BASIS_CREATE_START(CM%ID_M,BASIS_M,ERR,ERROR,*999)
      !Set Lagrange/Simplex (CM%IT_T) for BASIS_M
      CALL BASIS_TYPE_SET(BASIS_M,CM%IT_T,ERR,ERROR,*999)
      !Set number of XI (CM%D)
      CALL BASIS_NUMBER_OF_XI_SET(BASIS_M,CM%D,ERR,ERROR,*999)
      !Set interpolation (CM%IT_M) for dimensions 
      IF (CM%D==2) THEN
        CALL BASIS_INTERPOLATION_XI_SET(BASIS_M,(/CM%IT_M,CM%IT_M/),ERR,ERROR,*999)
      ELSE IF (CM%D==3) THEN
        CALL BASIS_INTERPOLATION_XI_SET(BASIS_M,(/CM%IT_M,CM%IT_M,CM%IT_M/),ERR,ERROR,*999)
        CALL BASIS_QUADRATURE_NUMBER_OF_GAUSS_XI_SET(BASIS_M,(/3,3,3/),ERR,ERROR,*999)
      ELSE
        GOTO 999
      END IF
  CALL BASIS_CREATE_FINISH(BASIS_M,ERR,ERROR,*999)

  NULLIFY(BASIS_V)
  !Velocity basis BASIS_V (CM%ID_V)
  CALL BASIS_CREATE_START(CM%ID_V,BASIS_V,ERR,ERROR,*999)
      !Set Lagrange/Simplex (CM%IT_T) for BASIS_V
      CALL BASIS_TYPE_SET(BASIS_V,CM%IT_T,ERR,ERROR,*999)
      !Set number of XI (CM%D)
      CALL BASIS_NUMBER_OF_XI_SET(BASIS_V,CM%D,ERR,ERROR,*999)
      !Set interpolation (CM%IT_V) for dimensions 
      IF (CM%D==2) THEN
        CALL BASIS_INTERPOLATION_XI_SET(BASIS_V,(/CM%IT_V,CM%IT_V/),ERR,ERROR,*999)
      ELSE IF (CM%D==3) THEN
        CALL BASIS_INTERPOLATION_XI_SET(BASIS_V,(/CM%IT_V,CM%IT_V,CM%IT_V/),ERR,ERROR,*999)
        CALL BASIS_QUADRATURE_NUMBER_OF_GAUSS_XI_SET(BASIS_V,(/3,3,3/),ERR,ERROR,*999)
      ELSE
        GOTO 999
      END IF
  CALL BASIS_CREATE_FINISH(BASIS_V,ERR,ERROR,*999)

  NULLIFY(BASIS_P)
  !Spatial pressure BASIS_P (CM%ID_P)
  CALL BASIS_CREATE_START(CM%ID_P,BASIS_P,ERR,ERROR,*999)
      !Set Lagrange/Simplex (CM%IT_T) for BASIS_P
      CALL BASIS_TYPE_SET(BASIS_P,CM%IT_T,ERR,ERROR,*999)
      !Set number of XI (CM%D)
      CALL BASIS_NUMBER_OF_XI_SET(BASIS_P,CM%D,ERR,ERROR,*999)
      !Set interpolation (CM%IT_P) for dimensions 
      IF (CM%D==2) THEN
        CALL BASIS_INTERPOLATION_XI_SET(BASIS_P,(/CM%IT_P,CM%IT_P/),ERR,ERROR,*999)
      ELSE IF (CM%D==3) THEN
        CALL BASIS_INTERPOLATION_XI_SET(BASIS_P,(/CM%IT_P,CM%IT_P,CM%IT_P/),ERR,ERROR,*999)
        CALL BASIS_QUADRATURE_NUMBER_OF_GAUSS_XI_SET(BASIS_P,(/3,3,3/),ERR,ERROR,*999)
      ELSE
        GOTO 999
      END IF
  CALL BASIS_CREATE_FINISH(BASIS_P,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Create a mesh with three mesh components for different field interpolations
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Define number of mesh components
  MESH_NUMBER_OF_COMPONENTS=3

  NULLIFY(NODES)
  ! Define number of nodes (CM%N_T)
  CALL NODES_CREATE_START(REGION,CM%N_T,NODES,ERR,ERROR,*999)
  CALL NODES_CREATE_FINISH(NODES,ERR,ERROR,*999)

  NULLIFY(MESH)
  ! Define 2D/3D (CM%D) mesh 
  CALL MESH_CREATE_START(1,REGION,CM%D,MESH,ERR,ERROR,*999)
      !Set number of elements (CM%E_T)
      CALL MESH_NUMBER_OF_ELEMENTS_SET(MESH,CM%E_T,ERR,ERROR,*999)
      !Set number of mesh components
      CALL MESH_NUMBER_OF_COMPONENTS_SET(MESH,MESH_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)

      !Specify spatial mesh component (CM%ID_M)
      NULLIFY(MESH_ELEMENTS_M)
      CALL MESH_TOPOLOGY_ELEMENTS_CREATE_START(MESH,CM%ID_M,BASIS_M,MESH_ELEMENTS_M,ERR,ERROR,*999)
          !Define mesh topology (MESH_ELEMENTS_M) using all elements' (CM%E_T) associations (CM%M(k,1:CM%EN_M))
          DO k=1,CM%E_T
            CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(k,MESH_ELEMENTS_M, &
            CM%M(k,1:CM%EN_M),ERR,ERROR,*999)
          END DO
      CALL MESH_TOPOLOGY_ELEMENTS_CREATE_FINISH(MESH,CM%ID_M,ERR,ERROR,*999)

      !Specify velocity mesh component (CM%ID_V)
      NULLIFY(MESH_ELEMENTS_V)
      !Velocity:
      CALL MESH_TOPOLOGY_ELEMENTS_CREATE_START(MESH,CM%ID_V,BASIS_V,MESH_ELEMENTS_V,ERR,ERROR,*999)
          !Define mesh topology (MESH_ELEMENTS_V) using all elements' (CM%E_T) associations (CM%V(k,1:CM%EN_V))
          DO k=1,CM%E_T
            CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(k,MESH_ELEMENTS_V, &
            CM%V(k,1:CM%EN_V),ERR,ERROR,*999)
          END DO
      CALL MESH_TOPOLOGY_ELEMENTS_CREATE_FINISH(MESH,CM%ID_V,ERR,ERROR,*999)

      !Specify pressure mesh component (CM%ID_P)
      NULLIFY(MESH_ELEMENTS_P)
      !Pressure:
      CALL MESH_TOPOLOGY_ELEMENTS_CREATE_START(MESH,CM%ID_P,BASIS_P,MESH_ELEMENTS_P,ERR,ERROR,*999)
          !Define mesh topology (MESH_ELEMENTS_P) using all elements' (CM%E_T) associations (CM%P(k,1:CM%EN_P))
          DO k=1,CM%E_T
            CALL MESH_TOPOLOGY_ELEMENTS_ELEMENT_NODES_SET(k,MESH_ELEMENTS_P, &
            CM%P(k,1:CM%EN_P),ERR,ERROR,*999)
          END DO
      CALL MESH_TOPOLOGY_ELEMENTS_CREATE_FINISH(MESH,CM%ID_P,ERR,ERROR,*999)

  CALL MESH_CREATE_FINISH(MESH,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Create a decomposition for mesh
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(DECOMPOSITION)
  !Define decomposition user number
  DECOMPOSITION_USER_NUMBER=1
  !Perform decomposition
  CALL DECOMPOSITION_CREATE_START(DECOMPOSITION_USER_NUMBER,MESH,DECOMPOSITION,ERR,ERROR,*999)
      !Set the decomposition to be a general decomposition with the specified number of domains
      CALL DECOMPOSITION_TYPE_SET(DECOMPOSITION,DECOMPOSITION_CALCULATED_TYPE,ERR,ERROR,*999)
      CALL DECOMPOSITION_NUMBER_OF_DOMAINS_SET(DECOMPOSITION,NUMBER_COMPUTATIONAL_NODES,ERR,ERROR,*999)
  CALL DECOMPOSITION_CREATE_FINISH(MESH,DECOMPOSITION,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define geometric field
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(GEOMETRIC_FIELD)
  !Set X,Y,Z direction parameters
  X_DIRECTION=1
  Y_DIRECTION=2
  Z_DIRECTION=3
  !Set geometric field user number
  GEOMETRIC_FIELD_USER_NUMBER=1

  !Create geometric field
  CALL FIELD_CREATE_START(GEOMETRIC_FIELD_USER_NUMBER,REGION,GEOMETRIC_FIELD,ERR,ERROR,*999)
      !Set field geometric type
      CALL FIELD_TYPE_SET(GEOMETRIC_FIELD,FIELD_GEOMETRIC_TYPE,ERR,ERROR,*999)
      !Set decomposition
      CALL FIELD_MESH_DECOMPOSITION_SET(GEOMETRIC_FIELD,DECOMPOSITION,ERR,ERROR,*999)
      !Disable scaling      
      CALL FIELD_SCALING_TYPE_SET(GEOMETRIC_FIELD,FIELD_NO_SCALING,ERR,ERROR,*999)	
      !Set field component to mesh component for each dimension
      CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,X_DIRECTION,CM%ID_M,ERR,ERROR,*999)
      CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,Y_DIRECTION,CM%ID_M,ERR,ERROR,*999)
      IF(CM%D==3) THEN
      CALL FIELD_COMPONENT_MESH_COMPONENT_SET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,Z_DIRECTION,CM%ID_M,ERR,ERROR,*999)
      ENDIF
  CALL FIELD_CREATE_FINISH(GEOMETRIC_FIELD,ERR,ERROR,*999)

  !Set geometric field parameters (CM%N(k,j)) and do update
  DO k=1,CM%N_M
    DO j=1,CM%D
      CALL FIELD_PARAMETER_SET_UPDATE_NODE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,CM%ID_M,k,j, &
        & CM%N(k,j),ERR,ERROR,*999)
    END DO
  END DO
  CALL FIELD_PARAMETER_SET_UPDATE_START(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
  CALL FIELD_PARAMETER_SET_UPDATE_FINISH(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Create equations set
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(EQUATIONS_SET)

  !Set the equations set to be a Stokes Flow problem
  CALL EQUATIONS_SET_CREATE_START(1,REGION,GEOMETRIC_FIELD,EQUATIONS_SET,ERR,ERROR,*999)
    CALL EQUATIONS_SET_SPECIFICATION_SET(EQUATIONS_SET,EQUATIONS_SET_FLUID_MECHANICS_CLASS, & 
      & EQUATIONS_SET_NAVIER_STOKES_EQUATION_TYPE,EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE,ERR,ERROR,*999)
  CALL EQUATIONS_SET_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define dependent field and initialise
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Create the equations set dependent field variables
  NULLIFY(DEPENDENT_FIELD)
  CALL EQUATIONS_SET_DEPENDENT_CREATE_START(EQUATIONS_SET,2,DEPENDENT_FIELD,ERR,ERROR,*999)
  CALL EQUATIONS_SET_DEPENDENT_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)


  !Initialise dependent field u=0,v=0,w=-1  
  CALL FIELD_COMPONENT_VALUES_INITIALISE(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,&
  &FIELD_VALUES_SET_TYPE,1,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_VALUES_INITIALISE(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,&
  &FIELD_VALUES_SET_TYPE,2,0.0_DP,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_VALUES_INITIALISE(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,&
  &FIELD_VALUES_SET_TYPE,3,-1.0_DP,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define material field and initialise
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Create the equations set materials field variables
  NULLIFY(MATERIALS_FIELD)
  CALL EQUATIONS_SET_MATERIALS_CREATE_START(EQUATIONS_SET,3,MATERIALS_FIELD,ERR,ERROR,*999)
  CALL EQUATIONS_SET_MATERIALS_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)
  
  CALL FIELD_COMPONENT_VALUES_INITIALISE(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,&
  &FIELD_VALUES_SET_TYPE,1,1.0_DP,ERR,ERROR,*999)
  CALL FIELD_COMPONENT_VALUES_INITIALISE(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,&
  &FIELD_VALUES_SET_TYPE,2,1.0_DP,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define equations
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(EQUATIONS)
  CALL EQUATIONS_SET_EQUATIONS_CREATE_START(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
  !Set matrix lumping
  CALL EQUATIONS_LUMPING_TYPE_SET(EQUATIONS,EQUATIONS_UNLUMPED_MATRICES,ERR,ERROR,*999)
  !CALL EQUATIONS_LUMPING_TYPE_SET(EQUATIONS,EQUATIONS_LUMPED_MATRICES,ERR,ERROR,*999)
  !Set the equations matrices sparsity type
  CALL EQUATIONS_SPARSITY_TYPE_SET(EQUATIONS,EQUATIONS_SPARSE_MATRICES,ERR,ERROR,*999)
!   CALL EQUATIONS_OUTPUT_TYPE_SET(EQUATIONS,EQUATIONS_ELEMENT_MATRIX_OUTPUT,ERR,ERROR,*999)
  CALL EQUATIONS_SET_EQUATIONS_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define boundary conditions (temporary approach)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  !Create the equations set boundar conditions
  NULLIFY(BOUNDARY_CONDITIONS)
  CALL EQUATIONS_SET_BOUNDARY_CONDITIONS_CREATE_START(EQUATIONS_SET,BOUNDARY_CONDITIONS,ERR,ERROR,*999)
  !Set boundary conditions
   CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,1,BOUNDARY_CONDITION_FIXED, &
     & 0.0_DP,ERR,ERROR,*999)
   CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,9,BOUNDARY_CONDITION_FIXED, &
     & 0.0_DP,ERR,ERROR,*999)
   CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(BOUNDARY_CONDITIONS,FIELD_U_VARIABLE_TYPE,17,BOUNDARY_CONDITION_FIXED, &
     & 1.0_DP,ERR,ERROR,*999)

  CALL EQUATIONS_SET_BOUNDARY_CONDITIONS_CREATE_FINISH(EQUATIONS_SET,ERR,ERROR,*999)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Define problem and solver settings
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  NULLIFY(PROBLEM)
  !Set the problem to be a standard Stokes problem
  CALL PROBLEM_CREATE_START(1,PROBLEM,ERR,ERROR,*999)
    CALL PROBLEM_SPECIFICATION_SET(PROBLEM,PROBLEM_FLUID_MECHANICS_CLASS,PROBLEM_NAVIER_STOKES_EQUATION_TYPE, &
    & PROBLEM_TRANSIENT_NAVIER_STOKES_SUBTYPE,ERR,ERROR,*999)
  CALL PROBLEM_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

  !Create the problem control loop
  NULLIFY(CONTROL_LOOP)
  CALL PROBLEM_CONTROL_LOOP_CREATE_START(PROBLEM,ERR,ERROR,*999)
  !Get the control loop
  CALL PROBLEM_CONTROL_LOOP_GET(PROBLEM,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
  !Set the times
  !start, end, delta t 
  CALL CONTROL_LOOP_TIMES_SET(CONTROL_LOOP,0.0_DP,2.0_DP,1.0_DP,ERR,ERROR,*999)
  CALL CONTROL_LOOP_TIME_OUTPUT_SET(CONTROL_LOOP,1,ERR,ERROR,*999)
  !Finish creating the problem control
  CALL PROBLEM_CONTROL_LOOP_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

  !Start the creation of the problem solvers
  NULLIFY(SOLVER)
  NULLIFY(LINEAR_SOLVER)
  NULLIFY(NONLINEAR_SOLVER)
  CALL PROBLEM_SOLVERS_CREATE_START(PROBLEM,ERR,ERROR,*999)
  CALL PROBLEM_SOLVER_GET(PROBLEM,CONTROL_LOOP_NODE,1,SOLVER,ERR,ERROR,*999)


  !Set solver parameters
  RELATIVE_TOLERANCE=1.0E-5_DP !default: 1.0E-05_DP
  ABSOLUTE_TOLERANCE=1.0E-10_DP !default: 1.0E-10_DP
  DIVERGENCE_TOLERANCE=1.0E5 !default: 1.0E5
  MAXIMUM_ITERATIONS=100000 !default: 100000
  RESTART_VALUE=300 !default: 30

  !Set dynamic solver settings
  !CALL SOLVER_OUTPUT_TYPE_SET(SOLVER,SOLVER_NO_OUTPUT,ERR,ERROR,*999)
  !CALL SOLVER_OUTPUT_TYPE_SET(SOLVER,SOLVER_PROGRESS_OUTPUT,ERR,ERROR,*999)
  !CALL SOLVER_OUTPUT_TYPE_SET(SOLVER,SOLVER_TIMING_OUTPUT,ERR,ERROR,*999)
  !CALL SOLVER_OUTPUT_TYPE_SET(SOLVER,SOLVER_SOLVER_OUTPUT,ERR,ERROR,*999)
!   CALL SOLVER_OUTPUT_TYPE_SET(SOLVER,SOLVER_MATRIX_OUTPUT,ERR,ERROR,*999)
  !CALL SOLVER_DYNAMIC_SCHEME_SET(SOLVER,SOLVER_DYNAMIC_EULER_SCHEME,ERR,ERROR,*999)
  !CALL SOLVER_DYNAMIC_SCHEME_SET(SOLVER,SOLVER_DYNAMIC_BACKWARD_EULER_SCHEME,ERR,ERROR,*999)
  !CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_SECOND_DEGREE,ERR,ERROR,*999)
  !CALL SOLVER_DYNAMIC_SCHEME_SET(SOLVER,SOLVER_DYNAMIC_SECOND_DEGREE_GEAR_SCHEME,ERR,ERROR,*999)
  

  !Set nonlinear solver settings
  !Get the associated nonlinear solver
  CALL SOLVER_DYNAMIC_NONLINEAR_SOLVER_GET(SOLVER,NONLINEAR_SOLVER,ERR,ERROR,*999)
!   CALL SOLVER_OUTPUT_TYPE_SET(NONLINEAR_SOLVER,SOLVER_MATRIX_OUTPUT,ERR,ERROR,*999)
 CALL SOLVER_OUTPUT_TYPE_SET(NONLINEAR_SOLVER,SOLVER_PROGRESS_OUTPUT,ERR,ERROR,*999)
  CALL SOLVER_NEWTON_JACOBIAN_CALCULATION_TYPE_SET(NONLINEAR_SOLVER,SOLVER_NEWTON_JACOBIAN_ANALTYIC_CALCULATED,ERR,ERROR,*999)
!    CALL SOLVER_NEWTON_JACOBIAN_CALCULATION_TYPE_SET(SOLVER,SOLVER_NEWTON_JACOBIAN_FD_CALCULATED,ERR,ERROR,*999)
  CALL SOLVER_NEWTON_ABSOLUTE_TOLERANCE_SET(NONLINEAR_SOLVER,ABSOLUTE_TOLERANCE,ERR,ERROR,*999)
!   CALL SOLVER_NEWTON_RELATIVE_TOLERANCE_SET(SOLVER,ABSOLUTE_TOLERANCE,ERR,ERROR,*999)
!   CALL SOLVER_NEWTON_LINESEARCH_ALPHA_SET(SOLVER,LINESEARCH_ALPHA,ERR,ERROR,*999)

!     CALL SOLVER_OUTPUT_TYPE_SET(LINEAR_SOLVER,SOLVER_MATRIX_OUTPUT,ERR,ERROR,*999)
    !CALL SOLVER_OUTPUT_TYPE_SET(LINEAR_SOLVER,SOLVER_PROGRESS_OUTPUT,ERR,ERROR,*999)

  !Set linear solver settings
  !Get the associated linear solver
  CALL SOLVER_NEWTON_LINEAR_SOLVER_GET(NONLINEAR_SOLVER,LINEAR_SOLVER,ERR,ERROR,*999)
  CALL SOLVER_LINEAR_ITERATIVE_MAXIMUM_ITERATIONS_SET(LINEAR_SOLVER,300,ERR,ERROR,*999)
!   CALL SOLVER_LINEAR_ITERATIVE_DIVERGENCE_TOLERANCE_SET(LINEAR_SOLVER,DIVERGENCE_TOLERANCE,ERR,ERROR,*999)
!   CALL SOLVER_LINEAR_ITERATIVE_ABSOLUTE_TOLERANCE_SET(LINEAR_SOLVER,ABSOLUTE_TOLERANCE,ERR,ERROR,*999)
!   CALL SOLVER_LINEAR_ITERATIVE_RELATIVE_TOLERANCE_SET(LINEAR_SOLVER,RELATIVE_TOLERANCE,ERR,ERROR,*999)
!   CALL SOLVER_LINEAR_ITERATIVE_MAXIMUM_ITERATIONS_SET(LINEAR_SOLVER,MAXIMUM_ITERATIONS,ERR,ERROR,*999)
  CALL SOLVER_LINEAR_ITERATIVE_GMRES_RESTART_SET(LINEAR_SOLVER,RESTART_VALUE,ERR,ERROR,*999)



  !Finish the creation of the problem solvers
  CALL PROBLEM_SOLVERS_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)

  !Create the problem solver equations
  NULLIFY(SOLVER)
  NULLIFY(SOLVER_EQUATIONS)
  CALL PROBLEM_SOLVER_EQUATIONS_CREATE_START(PROBLEM,ERR,ERROR,*999)
    CALL PROBLEM_SOLVER_GET(PROBLEM,CONTROL_LOOP_NODE,1,SOLVER,ERR,ERROR,*999)
    CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)

    CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
    !Add in the equations set
    CALL SOLVER_EQUATIONS_EQUATIONS_SET_ADD(SOLVER_EQUATIONS,EQUATIONS_SET,EQUATIONS_SET_INDEX,ERR,ERROR,*999)

  CALL PROBLEM_SOLVER_EQUATIONS_CREATE_FINISH(PROBLEM,ERR,ERROR,*999)


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Solve the problem
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

WRITE(*,*)'start solving...'

 CALL PROBLEM_SOLVE(PROBLEM,ERR,ERROR,*999)
     WRITE(*,*)'Problem solved...'
WRITE(*,*)'finishing solving...'

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!Afterburner
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   FILE="cmgui"
   METHOD="FORTRAN"

   EXPORT_FIELD=.FALSE.
   IF(EXPORT_FIELD) THEN
     WRITE(*,*)'Now export fields...'
    CALL FLUID_MECHANICS_IO_WRITE_CMGUI(REGION,FILE,ERR,ERROR,*999)
     WRITE(*,*)'All fields exported...'
!     CALL FIELD_IO_NODES_EXPORT(REGION%FIELDS, FILE, METHOD, ERR,ERROR,*999)  
!     CALL FIELD_IO_ELEMENTS_EXPORT(REGION%FIELDS, FILE, METHOD, ERR,ERROR,*999)
   ENDIF

   !Calculate the stop times and write out the elapsed user and system times
   CALL CPU_TIMER(USER_CPU,STOP_USER_TIME,ERR,ERROR,*999)
   CALL CPU_TIMER(SYSTEM_CPU,STOP_SYSTEM_TIME,ERR,ERROR,*999)

   CALL WRITE_STRING_TWO_VALUE(GENERAL_OUTPUT_TYPE,"User time = ",STOP_USER_TIME(1)-START_USER_TIME(1),", System time = ", &
     & STOP_SYSTEM_TIME(1)-START_SYSTEM_TIME(1),ERR,ERROR,*999)


!   this causes issues
!   CALL CMISS_FINALISE(ERR,ERROR,*999)

   WRITE(*,'(A)') "**********************************"
   WRITE(*,'(A)') "NOT REALLY COMPLETED SUCCESSFULLY."
   WRITE(*,'(A)') "**********************************"

   STOP
999 CALL CMISS_WRITE_ERROR(ERR,ERROR)
   STOP

END PROGRAM NavierStokesFlow
