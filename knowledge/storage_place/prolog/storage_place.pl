:- module(storage_place,
    [
        storage_area/2,
        storage_place/4
    ]).

:- use_module(library('semweb/rdfs')).
:- use_module(library('semweb/rdf_db')).

:- rdf_db:rdf_register_ns(knowrob, 'http://knowrob.org/kb/knowrob.owl#',  [keep(true)]).
:- rdf_register_prefix(suturo_storage_place, 'http://knowrob.org/kb/suturo_storage_place.owl#').
:- rdf_register_prefix(suturo_object, 'http://knowrob.org/kb/suturo_object.owl#').

:- rdf_meta 
    storage_area(r, -),
	storage_place(r, -, -, -),
    get_position(r, -, -, -),
    get_scale(r, -, -).

get_position(PositionIndividual, X, Y, Z):-
    rdf(PositionIndividual, knowrob:'xCoord', XRaw),
    strip_literal_type(XRaw, XValue),
    atom_number(XValue, X),
    rdf(PositionIndividual, knowrob:'yCoord', YRaw),
    strip_literal_type(YRaw, YValue),
    atom_number(YValue, Y),
    rdf(PositionIndividual, knowrob:'zCoord', ZRaw),
    strip_literal_type(ZRaw, ZValue),
    atom_number(ZValue, Z).

get_scale(StorageAreaIndividual, Width, Height):-
    rdf(StorageAreaIndividual, knowrob:'widthOfObject', WRaw),
    strip_literal_type(WRaw, WValue),
    atom_number(WValue, Width),
    rdf(StorageAreaIndividual, knowrob:'heightOfObject', HRaw),
    strip_literal_type(HRaw, HValue),
    atom_number(HValue, Height).

storage_area(ObjectClass, StorageAreaIndividual):-
    rdfs_individual_of(StorageAreaIndividual, suturo_storage_place:'StorageArea'),
    rdfs_type_of(StorageAreaIndividual, StorageAreaClass),
    owl_class_properties_all(StorageAreaClass, suturo_storage_place:'storagePlaceFor', StorageAreaForClass),
    rdfs_subclass_of(ObjectClass, StorageAreaForClass).

storage_area(ObjectClass, StorageAreaIndividual):-
    rdfs_individual_of(StorageAreaIndividual, suturo_storage_place:'StorageArea'),
    rdfs_type_of(StorageAreaIndividual, StorageAreaClass),
    owl_class_properties_all(StorageAreaClass, suturo_storage_place:'storagePlaceFor', StorageAreaForRestriction),
    owl_restriction(StorageAreaForRestriction, restriction(Property,all_values_from(Range))),
    owl_class_properties_all(ObjectClass, Property, Range).

storage_place(ObjectClass, [X, Y, Z], Width, Height):-
    storage_area(ObjectClass, StorageAreaIndividual),
    rdf_has(StorageAreaIndividual, knowrob:'locatedAtAbsolute', PositionIndividual),
    get_position(PositionIndividual, X, Y, Z),
    get_scale(StorageAreaIndividual, Width, Height).