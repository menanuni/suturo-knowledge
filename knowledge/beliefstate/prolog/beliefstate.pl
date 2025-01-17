:- module(beliefstate,
    [
      clear/0,
      mesh_path/2,
      object_exists/1,
      process_perceive_action/3,         
      process_grasp_action/3,         
      process_drop_action/1,
      object_attached_to_gripper/2,
      get_latest_object_pose/2,
      get_latest_grasp_pose/2,
      get_objects_on_kitchen_island_counter/1,
      get_two_objects_on_kitchen_island_counter_with_same_storage_place/2,
      get_top_grasp_pose/2,
      remove_object/1
    ]).

:- use_module(library('semweb/rdfs')).
:- use_module(library('semweb/rdf_db')).
:- use_module(library('knowrob/rdfs')).

:- rdf_db:rdf_register_ns(knowrob, 'http://knowrob.org/kb/knowrob.owl#',  [keep(true)]).
:- rdf_db:rdf_register_ns(rdf, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', [keep(true)]).
:- rdf_db:rdf_register_ns(xsd, 'http://www.w3.org/2001/XMLSchema#', [keep(true)]).

:- rdf_register_prefix(suturo_action, 'http://knowrob.org/kb/suturo_action.owl#').
:- rdf_register_prefix(suturo_object, 'http://knowrob.org/kb/suturo_object.owl#').

:-  rdf_meta
    remove_object(r),
    get_top_grasp_pose(r, -),
    mesh_path(r, -),
    object_exists(r),
    process_perceive_action(r,+, +),
    process_grasp_action(r,r, +),
    process_drop_action(r),
    object_attached_to_gripper(r,-),
    get_latest_action_associated_with_object(r,-),
    get_latest_object_pose(r, -),
    get_latest_grasp_pose(r, -),
    assert_new_individual(r, -),
    assert_new_pose(+, +, -),
    assert_new_pose_in_gripper_frame(r, +, -),
    assert_new_pose_from_gripper_frame(r, +, -),
    print_beliefstate_intern(+),
    get_all_object_individuals(-),
    get_first_actions_associated_with_object(r, -),
    get_actions_associated_with_object(r, -),
    get_actions_associated_with_object_intern(r, +, -),
    print_actions(+),
    print_action_info(r),
    get_pose_info(r, -),
    get_used_gripper_info(r, +, -).

remove_object(ObjectClass):-
    rdfs_type_of(ObjectIndividual, ObjectClass),
    forall(rdf_has(ActionIndvidual, knowrob:'objectActedOn', ObjectIndividual), rdf_retractall(ActionIndvidual,_,_)),
    rdf_retractall(ObjectIndividual,_,_),
    print_beliefstate,!.

get_top_grasp_pose(ObjectClass, [[GX,GY,GZ],[GQX,GQY,GQZ,GQW]]):-
    owl_class_properties_value(ObjectClass, suturo_object:'graspableAt', GraspPoseIndividual),
    rdfs_type_of(GraspPoseIndividual, suturo_object:'TopGrasp'),
    get_pose(GraspPoseIndividual, [[GX,GY,GZ],[GQX,GQY,GQZ,GQW]]).

clear:-
    forall(rdf_has(J, _, _, belief_state), rdf_retractall(J,_,_)),
    ros_info('beliefstate cleared!!!!'),
    ros_info('###################################').

mesh_path(ObjectClass, MeshPath):-
    owl_class_properties_value(ObjectClass, knowrob:'pathToCadModel', Temp),
    strip_literal_type(Temp, MeshPath).

object_exists(ObjectClass):-
    rdfs_individual_of(_, ObjectClass).

process_perceive_action(ObjectClass, PoseList, ReferenceFrame):-
    assert_new_individual(knowrob:'SiftPerception', PerceptionActionIndividual),
    (rdfs_individual_of(ObjectIndividual, ObjectClass) ->
        get_latest_action_associated_with_object(ObjectIndividual, LatestActionIndividual),
        rdf_assert(LatestActionIndividual, knowrob:'nextEvent', PerceptionActionIndividual, belief_state)
        ;
        assert_new_individual(ObjectClass, ObjectIndividual)
    ),!,
    nth0(0, PoseList, Position),
    nth0(1, PoseList, Quaternion),
    tf_transform_pose(ReferenceFrame, '/map', pose(Position, Quaternion), pose(MapPosition, MapQuaternion)),
    assert_new_pose([MapPosition, MapQuaternion], '/map', PoseIndividual),
    rdf_assert(PerceptionActionIndividual, knowrob:'detectedObject', ObjectIndividual, belief_state),
    rdf_assert(PerceptionActionIndividual, knowrob:'eventOccursAt', PoseIndividual, belief_state),
    print_beliefstate,!.
    
process_grasp_action(ObjectClass, GripperIndividual, GraspPoseList):-
    assert_new_individual(knowrob:'GraspingSomething', GraspActionIndividual),
    rdfs_individual_of(ObjectIndividual, ObjectClass),
    get_latest_action_associated_with_object(ObjectIndividual, LatestActionIndividual),
    rdf_assert(LatestActionIndividual, knowrob:'nextEvent', GraspActionIndividual, belief_state),
    rdf_has(LatestActionIndividual, knowrob:'eventOccursAt', LatestPoseIndividual),
    get_pose(LatestPoseIndividual, MapPoseList),
    assert_new_pose_in_gripper_frame(GripperIndividual, MapPoseList, LocalPoseIndividual),
    rdf_assert(GraspActionIndividual, knowrob:'objectActedOn', ObjectIndividual, belief_state),
    rdf_assert(GraspActionIndividual, knowrob:'deviceUsed', GripperIndividual, belief_state),
    rdf_assert(GraspActionIndividual, knowrob:'eventOccursAt', LocalPoseIndividual, belief_state),
    assert_new_pose(GraspPoseList, 'object_frame', GraspPoseIndividual),
    rdf_assert(GraspActionIndividual, suturo_action:'gripperPose', GraspPoseIndividual, belief_state),
    print_beliefstate,!.
    
process_drop_action(GripperIndividual):-
    assert_new_individual(knowrob:'RealisingGraspOfSomething', DropActionIndividual),
    object_attached_to_gripper(GripperIndividual, ObjectIndividual),
    get_latest_action_associated_with_object(ObjectIndividual, GraspActionIndividual),
    rdf_assert(GraspActionIndividual, knowrob:'nextEvent', DropActionIndividual, belief_state),
    rdf_has(GraspActionIndividual, knowrob:'eventOccursAt', LatestPoseIndividual),
    get_pose(LatestPoseIndividual, LocalPoseList),
    assert_new_pose_from_gripper_frame(GripperIndividual, LocalPoseList, GlobalPoseIndividual),
    rdf_assert(DropActionIndividual, knowrob:'objectActedOn', ObjectIndividual, belief_state),
    rdf_assert(DropActionIndividual, knowrob:'deviceUsed', GripperIndividual, belief_state),
    rdf_assert(DropActionIndividual, knowrob:'eventOccursAt', GlobalPoseIndividual, belief_state),
    print_beliefstate,!.

object_attached_to_gripper(GripperIndividual, ObjectIndividual):-
    rdfs_individual_of(GraspActionIndividual, knowrob:'GraspingSomething'),
    \+(rdf_has(GraspActionIndividual, knowrob:'nextEvent', _)),
    rdf_has(GraspActionIndividual, knowrob:'deviceUsed', GripperIndividual),
    rdf_has(GraspActionIndividual, knowrob:'objectActedOn', ObjectIndividual).

get_latest_action_associated_with_object(ObjectIndividual, ActionIndvidual):-
    rdfs_individual_of(ActionIndvidual, knowrob:'Event'),
    rdf_has(ActionIndvidual, knowrob:'objectActedOn', ObjectIndividual),
    \+(rdf_has(ActionIndvidual, knowrob:'nextEvent', _)).

get_latest_object_pose(ObjectIndividual, PoseList):- 
    get_latest_action_associated_with_object(ObjectIndividual, ActionIndvidual),
    rdf_has(ActionIndvidual, knowrob:'eventOccursAt', PoseIndividual),
    get_pose(PoseIndividual, PoseList).

get_latest_grasp_pose(ObjectClass, GraspPoseList):-
    rdfs_individual_of(ObjectIndividual, ObjectClass),
    get_latest_action_associated_with_object(ObjectIndividual, ActionIndvidual),
    rdf(ActionIndvidual, rdf:type, knowrob:'GraspingSomething'),
    rdf_has(ActionIndvidual, suturo_action:'gripperPose', GraspPoseIndividual),
    transform_data(GraspPoseIndividual, (GraspPoseTranslation, GraspPoseQuaternion)),
    append([GraspPoseTranslation], [GraspPoseQuaternion], GraspPoseList).

assert_new_individual(ObjectClass, ObjectIndividual):-
    rdf_instance_from_class(ObjectClass, belief_state, ObjectIndividual),
    rdf_assert(ObjectIndividual, rdf:type, owl:'NamedIndividual', belief_state).

assert_new_pose(PoseList, ReferenceFrame, PoseIndividual):-
    get_translation(PoseList, Translation),
    get_rotation(PoseList, Rotation),
    rdf_instance_from_class(knowrob:'Pose', belief_state, PoseIndividual),
    rdf_assert(PoseIndividual, rdf:type, owl:'NamedIndividual', belief_state),
    rdf_assert(PoseIndividual, knowrob:'translation', literal(type(xsd:string,Translation)), belief_state),
    rdf_assert(PoseIndividual, knowrob:'quaternion', literal(type(xsd:string,Rotation)), belief_state),
    rdf_assert(PoseIndividual, suturo_action:'referenceFrame', literal(type(xsd:string,ReferenceFrame)), belief_state).

assert_new_pose_in_gripper_frame(GripperIndividual, MapPoseList, LocalPoseIndividual):-
    nth0(0, MapPoseList, Position),
    nth0(1, MapPoseList, Quaternion),
    (rdf_equal(GripperIndividual, suturo_action:'left_gripper') ->
        tf_transform_pose('/map', '/l_gripper_led_frame', pose(Position, Quaternion), pose(LocalGripperPosition, LocalGripperQuaternion)),
        assert_new_pose([LocalGripperPosition, LocalGripperQuaternion], 'l_gripper_led_frame', LocalPoseIndividual)
        ;
        tf_transform_pose('/map', '/l_gripper_led_frame', pose(Position, Quaternion), pose(LocalGripperPosition, LocalGripperQuaternion)),
        assert_new_pose([LocalGripperPosition, LocalGripperQuaternion], 'r_gripper_led_frame', LocalPoseIndividual)).

assert_new_pose_from_gripper_frame(GripperIndividual, LocalPoseList, GlobalPoseIndividual):-
    nth0(0, LocalPoseList, Position),
    nth0(1, LocalPoseList, Quaternion),
    (rdf_equal(GripperIndividual, suturo_action:'left_gripper') ->
        tf_transform_pose('/l_gripper_led_frame', '/map', pose(Position, Quaternion), pose(GlobalPosition, GlobalQuaternion)),
        assert_new_pose([GlobalPosition, GlobalQuaternion], '/map', GlobalPoseIndividual)
        ;
        tf_transform_pose('/r_gripper_led_frame', '/map', pose(Position, Quaternion), pose(GlobalPosition, GlobalQuaternion)),
        assert_new_pose([GlobalPosition, GlobalQuaternion], '/map', GlobalPoseIndividual)).

get_objects_on_kitchen_island_counter(ObjectIndividualList):-
    findall(ObjectIndividual , 
           (rdfs_individual_of(ActionIndvidual, knowrob:'SiftPerception'),
           \+(rdf_has(ActionIndvidual, knowrob:'nextEvent', _)),
           rdf_has(ActionIndvidual, knowrob:'objectActedOn', ObjectIndividual)),
           ObjectIndividualList).

get_two_objects_on_kitchen_island_counter_with_same_storage_place(Object1, Object2):-
    get_objects_on_kitchen_island_counter(ObjectList),
    length(ObjectList, Length),
    Length =:= 1,
    nth0(0, ObjectList, Object1),
    atom_concat('', 'None', Object2).

get_two_objects_on_kitchen_island_counter_with_same_storage_place(Object1, Object2):-
    get_objects_on_kitchen_island_counter(ObjectList),
    length(ObjectList, Length),
    Length =:= 0,
    atom_concat('', 'None', Object1),
    atom_concat('', 'None', Object2).

get_two_objects_on_kitchen_island_counter_with_same_storage_place(Object1, Object2):-
    get_objects_on_kitchen_island_counter(ObjectList),
    member(Object1, ObjectList),
    member(Object2, ObjectList),
    Object1 \= Object2,
    rdfs_type_of(Object1, ObjectClass1),
    rdfs_type_of(Object2, ObjectClass2),
    storage_area(ObjectClass1, StorageArea1),
    storage_area(ObjectClass2, StorageArea2),
    StorageArea1 == StorageArea2.

get_two_objects_on_kitchen_island_counter_with_same_storage_place(Object1, Object2):-
    get_objects_on_kitchen_island_counter(ObjectList),
    member(Object1, ObjectList),
    rdfs_individual_of(ActionIndvidual1, knowrob:'RealisingGraspOfSomething'),
    rdfs_individual_of(ActionIndvidual2, knowrob:'RealisingGraspOfSomething'),
    ActionIndvidual1 \= ActionIndvidual2,
    rdf_has(ActionIndvidual1, knowrob:'objectActedOn', StoredObjectIndividual1),
    rdf_has(ActionIndvidual1, knowrob:'objectActedOn', StoredObjectIndividual2),
    rdfs_type_of(StoredObjectIndividual1, StoredObjectClass1),
    rdfs_type_of(StoredObjectIndividual2, StoredObjectClass2),
    rdfs_type_of(Object1, ObjectClass),
    storage_area(StoredObjectClass1, StorageArea),
    storage_area(StoredObjectClass2, StorageArea),
    storage_area(ObjectClass, StorageArea),
    atom_concat('', 'None', Object2).

get_two_objects_on_kitchen_island_counter_with_same_storage_place(Object1, Object2):-
    get_objects_on_kitchen_island_counter(ObjectList),
    length(ObjectList, Length),
    Length >= 2,
    nth0(0, ObjectList, Object1),
    nth0(1, ObjectList, Object2).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%

print_beliefstate:-
    ros_info('###################################'),
    get_all_object_individuals(ObjectIndividualList),
    print_beliefstate_intern(ObjectIndividualList),
    get_objects_on_kitchen_island_counter(ObjectList),
    object_list_to_atom(ObjectList, ObjectListAtom),
    atom_concat('Remaining objects: ' , ObjectListAtom, Temp),
    red_atom(Temp, RedObjectListAtom),
    ros_info(RedObjectListAtom).

print_beliefstate_intern([]).

print_beliefstate_intern([H|T]):-
    rdf_split_url(_,SimpleName, H),
    blue_atom(SimpleName, BlueSimpleName),
    ros_info(BlueSimpleName),
    get_actions_associated_with_object(H, ActionIndvidualList),
    print_actions(ActionIndvidualList),
    print_beliefstate_intern(T).

get_all_object_individuals(ObjectIndividualList):-
    findall(Temp, 
           (rdfs_individual_of(Temp, knowrob:'Sauce'); 
            rdfs_individual_of(Temp, knowrob:'Snacks');
            rdfs_individual_of(Temp, knowrob:'BreakfastCereal');
            rdfs_individual_of(Temp, knowrob:'Drink');
            rdfs_individual_of(Temp, knowrob:'FoodVessel')), 
            ObjectIndividualList).

get_first_action_associated_with_object(ObjectIndividual, ActionIndvidual):-
    rdfs_individual_of(ActionIndvidual, knowrob:'Event'),
    rdf_has(ActionIndvidual, knowrob:'objectActedOn', ObjectIndividual),
    \+(rdf_has(_, knowrob:'nextEvent', ActionIndvidual)).

get_actions_associated_with_object(ObjectIndividual, ActionIndvidualList):-
    get_first_action_associated_with_object(ObjectIndividual, FirstActionIndividual),
    get_actions_associated_with_object_intern(FirstActionIndividual, [FirstActionIndividual], ActionIndvidualList).

get_actions_associated_with_object_intern(CurrentActionIndividual, TempActionIndividualList, ActionIndvidualList):-
    \+(rdf_has(CurrentActionIndividual, knowrob:'nextEvent', _)),
    append(TempActionIndividualList, [], ActionIndvidualList).

get_actions_associated_with_object_intern(CurrentActionIndividual, TempActionIndividualList, ActionIndvidualList):-
    rdf_has(CurrentActionIndividual, knowrob:'nextEvent', NextActionIndividual),
    append(TempActionIndividualList, [NextActionIndividual], NewActionIndividualList),
    get_actions_associated_with_object_intern(NextActionIndividual, NewActionIndividualList, ActionIndvidualList).

print_actions([]).

print_actions([H|T]):-
    print_action_info(H),
    print_actions(T).

print_action_info(ActionIndvidual):-
    get_pose_info(ActionIndvidual, PoseInfoAtom),
    (rdfs_individual_of(ActionIndvidual, knowrob:'SiftPerception') ->
        atom_concat('PerceiveAction', ': ', ActionInfoAtom),
        atom_concat(ActionInfoAtom, PoseInfoAtom, WholeInfoAtom)
        ;
        (rdfs_individual_of(ActionIndvidual, knowrob:'GraspingSomething') ->
            atom_concat('GraspAction', ': ', ActionInfoAtom)
            ;
            atom_concat('DropAction', ': ', ActionInfoAtom)
        ),
        rdf_has(ActionIndvidual, knowrob:'deviceUsed', GripperIndividual),
        get_used_gripper_info(GripperIndividual, ActionInfoAtom, CurrentInfoAtom),
        atom_concat(CurrentInfoAtom, PoseInfoAtom, WholeInfoAtom)
    ),
    yellow_atom(WholeInfoAtom, WholeInfoYelloqAtom),
    ros_info(WholeInfoYelloqAtom).

get_pose_info(ActionIndvidual, PoseInfoAtom):-
    rdf_has(ActionIndvidual, knowrob:'eventOccursAt', PoseIndividual),
    get_pose(PoseIndividual, PoseList),
    get_reference_frame(PoseIndividual, ReferenceFrame),
    atom_concat(ReferenceFrame, ', ', TempReferenceFrame),
    pose_list_to_atom(PoseList, PoseListAtom),
    atom_concat(TempReferenceFrame, PoseListAtom, PoseInfoAtom).

get_used_gripper_info(GripperIndividual, CurrentInfoAtom, ModifiedInfoAtom):-
    (rdf_equal(GripperIndividual, suturo_action:'left_gripper') ->
        atom_concat(CurrentInfoAtom, 'leftGripper, ', ModifiedInfoAtom)
        ;
        atom_concat(CurrentInfoAtom, 'rightGripper, ', ModifiedInfoAtom)
    ).