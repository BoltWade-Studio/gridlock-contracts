#[dojo::contract]
mod GridLock {
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use gridlock::interface::system::IGridLockImpl;
    use gridlock::models::player::{Player, Move, PlayerProgress};
    use gridlock::models::map::{Map, MovableObjects, Obstacle, Size, Position};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        is_paused: bool,
        is_initialized: bool,
    }

    #[derive(Drop, Serde)]
    #[dojo::event]
    struct StartNewGame {
        #[key]
        player: ContractAddress,
        level: u32,
    }

    #[derive(Drop, Serde)]
    #[dojo::event]
    struct PlayerMoved {
        #[key]
        player: ContractAddress,
        object_id: u32,
        direction: felt252,
        level: u32,
        hit_id: u32,
        is_finished: bool,
        point: u256,
    }

    #[abi(embed_v0)]
    impl GridLockImpl of IGridLockImpl<ContractState> {
        fn initialize(ref self: ContractState, owner: ContractAddress) {
            assert(!self.is_initialized.read(), 'Already initialized');
            self.is_initialized.write(true);
            self.owner.write(owner);
        }

        fn update_map(
            ref self: ContractState,
            level: u32,
            size: Size,
            movable_objects: Span<MovableObjects>,
            obstacles: Span<Obstacle>,
        ) {
            self.assert_only_owner();
            self.assert_initialized();
            assert(level > 0, 'Level must be greater than 0');
            assert(size.width > 0 && size.height > 0, 'Invalid size');
            assert!(movable_objects.len() > 0, "Movable objects must be greater than 0");

            let mut new_movable_objects = array![];
            for movable_object in movable_objects {
                assert!(
                    *movable_object.id > 1,
                    "Object Id {} must be greater than 1",
                    *movable_object.id
                );
                assert(
                    *movable_object.position.x > 0 && *movable_object.position.x <= size.width,
                    'Invalid position'
                );
                assert(
                    *movable_object.position.y > 0 && *movable_object.position.y <= size.height,
                    'Invalid position'
                );
                assert(
                    *movable_object.size.width > 0 && *movable_object.size.height > 0,
                    'Invalid size'
                );
                assert(*movable_object.rotation <= 360, 'Invalid rotation');

                let mut new_x = *movable_object.position.x;
                let mut new_y = *movable_object.position.y;
                let mut new_width = *movable_object.size.width;
                let mut new_height = *movable_object.size.height;

                if *movable_object.rotation == 90 {
                    new_width = *movable_object.size.height;
                    new_height = *movable_object.size.width;
                    new_x = *movable_object.position.x - *movable_object.size.height + 1;
                } else if *movable_object.rotation == 180 {
                    new_x = *movable_object.position.x - *movable_object.size.width + 1;
                    new_y = *movable_object.position.y - *movable_object.size.height + 1;
                } else if *movable_object.rotation == 270 {
                    new_width = *movable_object.size.height;
                    new_height = *movable_object.size.width;
                    new_y = *movable_object.position.y - *movable_object.size.width + 1;
                }
                new_movable_objects
                    .append(
                        MovableObjects {
                            id: *movable_object.id,
                            name: *movable_object.name,
                            position: Position { x: new_x, y: new_y },
                            size: Size { width: new_width, height: new_height },
                            rotation: *movable_object.rotation,
                        }
                    );
            };

            let mut new_obstacles = array![];
            for obstacle in obstacles {
                assert(*obstacle.id > 0, 'Invalid id');
                assert(
                    *obstacle.position.x > 0 && *obstacle.position.x <= size.width,
                    'Invalid position'
                );
                assert(
                    *obstacle.position.y > 0 && *obstacle.position.y <= size.height,
                    'Invalid position'
                );
                assert(*obstacle.size.width > 0 && *obstacle.size.height > 0, 'Invalid size');
                assert(*obstacle.rotation <= 360, 'Invalid rotation');

                let mut new_x = *obstacle.position.x;
                let mut new_y = *obstacle.position.y;
                let mut new_width = *obstacle.size.width;
                let mut new_height = *obstacle.size.height;

                if *obstacle.rotation == 90 {
                    new_width = *obstacle.size.height;
                    new_height = *obstacle.size.width;
                    new_x = *obstacle.position.x - *obstacle.size.height + 1;
                } else if *obstacle.rotation == 180 {
                    new_x = *obstacle.position.x - *obstacle.size.width + 1;
                    new_y = *obstacle.position.y - *obstacle.size.height + 1;
                } else if *obstacle.rotation == 270 {
                    new_width = *obstacle.size.height;
                    new_height = *obstacle.size.width;
                    new_y = *obstacle.position.y - *obstacle.size.width + 1;
                }

                new_obstacles
                    .append(
                        Obstacle {
                            id: *obstacle.id,
                            name: *obstacle.name,
                            position: Position { x: new_x, y: new_y },
                            size: Size { width: new_width, height: new_height },
                            rotation: *obstacle.rotation,
                            is_movable: *obstacle.is_movable,
                            is_interactable: *obstacle.is_interactable,
                        }
                    );
            };

            let map = Map {
                level,
                size,
                movable_objects: new_movable_objects.span(),
                obstacles: new_obstacles.span(),
            };

            let mut world = self.world_default();
            world.write_model(@map);
        }

        fn start_new_game(ref self: ContractState) {
            self.assert_not_paused();

            let player = get_caller_address();
            let mut world = self.world_default();
            let mut player_data = self.get_player_data(player);

            let mut level = 1;
            if (player_data.progress.level != 0) {
                level = player_data.progress.level;
            }
            let map = self.get_map(level);
            player_data
                .progress =
                    PlayerProgress {
                        level,
                        size: map.size,
                        movable_objects: map.movable_objects,
                        obstacles: map.obstacles
                    };
            world.write_model(@player_data);

            world.emit_event(@StartNewGame { player, level });
        }

        fn move(ref self: ContractState, object_id: u32, direction: felt252) {
            self.assert_initialized();
            self.assert_not_paused();

            let player = get_caller_address();
            let mut world = self.world_default();
            let mut player_data: Player = world.read_model(player);
            let player_progress: PlayerProgress = player_data.progress;

            let mut is_target = false;
            let mut new_movable_objects: Array<MovableObjects> = array![];
            let map = self.parse_map(player_progress);
            let mut is_finished = true;
            let mut hit_id = 0;
            for movable_object in player_progress
                .movable_objects {
                    if *movable_object.id == object_id {
                        self.assert_valid_move(direction, *movable_object);
                        is_target = true;
                        let (new_movable_object, id) = self
                            .execute_move(*movable_object, direction, map);
                        new_movable_objects.append(new_movable_object);
                        if new_movable_object.position.x != 0
                            || new_movable_object.position.y != 0 {
                            is_finished = false;
                        }
                        hit_id = id;
                    } else {
                        if *movable_object.position.x != 0 || *movable_object.position.y != 0 {
                            is_finished = false;
                        }
                        new_movable_objects.append(*movable_object);
                    }
                };

            if !is_target {
                panic_with_felt252('object not found');
            }

            let mut level = player_data.progress.level;
            let mut obstacles = player_data.progress.obstacles;
            if is_finished {
                player_data.point = player_data.point + 100;
                player_data.progress.level = level + 1;
            } else {
                obstacles = self.update_obstacles(player_data.progress.obstacles);
            }

            player_data.progress.movable_objects = new_movable_objects.span();
            player_data.progress.obstacles = obstacles;
            world.write_model(@player_data);

            world
                .emit_event(
                    @PlayerMoved {
                        player,
                        object_id,
                        direction,
                        level,
                        hit_id,
                        is_finished,
                        point: player_data.point
                    }
                );
        }

        fn pause(ref self: ContractState) {
            self.assert_not_paused();
            self.assert_only_owner();
            self.is_paused.write(true);
        }

        fn unpause(ref self: ContractState) {
            self.assert_paused();
            self.assert_only_owner();
            self.is_paused.write(false);
        }

        fn get_map(self: @ContractState, level: u32) -> Map {
            let world = self.world_default();
            let map: Map = world.read_model(level);
            map
        }

        fn get_player_progress_map(
            self: @ContractState, address: ContractAddress
        ) -> Span<Span<u32>> {
            let world = self.world_default();
            let player: Player = world.read_model(address);
            self.parse_map(player.progress)
        }

        fn get_player_progress_map_index(
            self: @ContractState, address: ContractAddress, x: u32, y: u32
        ) -> u32 {
            let world = self.world_default();
            let player: Player = world.read_model(address);
            let map = self.parse_map(player.progress);
            *(*map.at(y)).at(x)
        }

        fn get_player_data(self: @ContractState, address: ContractAddress) -> Player {
            let world = self.world_default();
            let player: Player = world.read_model(address);
            player
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalImplTrait {
        fn assert_not_paused(self: @ContractState) {
            assert(!self.is_paused.read(), 'Contract is paused');
        }

        fn assert_paused(self: @ContractState) {
            assert(self.is_paused.read(), 'Contract is not paused');
        }

        fn assert_initialized(self: @ContractState) {
            assert(self.is_initialized.read(), 'Contract is not initialized');
        }

        fn assert_only_owner(self: @ContractState) {
            assert(self.owner.read() == get_caller_address(), 'Not owner');
        }

        fn assert_valid_move(self: @ContractState, direction: felt252, object: MovableObjects) {
            assert(
                direction == Move::UP.into()
                    || direction == Move::DOWN.into()
                    || direction == Move::LEFT.into()
                    || direction == Move::RIGHT.into(),
                'Invalid direction'
            );

            if direction == Move::UP.into() || direction == Move::DOWN.into() {
                assert(object.rotation == 0 || object.rotation == 180, 'Invalid rotation');
            } else {
                assert(object.rotation == 90 || object.rotation == 270, 'Invalid rotation');
            }
        }

        fn execute_move(
            ref self: ContractState,
            movable_object: MovableObjects,
            direction: felt252,
            map: Span<Span<u32>>
        ) -> (MovableObjects, u32) {
            let mut x = movable_object.position.x;
            let mut y = movable_object.position.y;
            let size = movable_object.size;
            let width = size.width;
            let height = size.height;

            let mut delta_x: u32 = 0;
            let mut delta_y: u32 = 0;

            if direction == Move::UP.into() {
                if y == 0 {
                    panic_with_felt252('Object has moved out')
                }
                delta_y = 2;
            } else if direction == Move::DOWN.into() {
                if y + height == size.clone().height + 1 {
                    panic_with_felt252('Object has moved out')
                }
                delta_y = 1;
            } else if direction == Move::LEFT.into() {
                if x == 0 {
                    panic_with_felt252('Object has moved out')
                }
                delta_x = 2;
            } else if direction == Move::RIGHT.into() {
                if x + width == size.clone().width + 1 {
                    panic_with_felt252('Object has moved out')
                }
                delta_x = 1;
            }

            let mut collision_ids: Array<u32> = array![];
            while collision_ids.is_empty() {
                if delta_x == 1 {
                    x = x + 1
                } else if delta_x == 2 {
                    x = x - 1
                }
                if delta_y == 1 {
                    y = y + 1
                } else if delta_y == 2 {
                    y = y - 1
                }
                if direction == Move::LEFT.into() {
                    for j in y
                        ..(y
                            + height) {
                                if *(*map.at(j)).at(x) == 0 {
                                    collision_ids.append(0);
                                    break;
                                };

                                if *(*map.at(j)).at(x) != 1
                                    && *(*map.at(j)).at(x) != movable_object.id {
                                    collision_ids.append(*(*map.at(x)).at(y));
                                }
                            }
                } else if direction == Move::RIGHT.into() {
                    for j in y
                        ..(y
                            + height) {
                                if *(*map.at(j)).at(x + width - 1) == 0 {
                                    collision_ids.append(0);
                                    break;
                                };

                                if *(*map.at(j)).at(x + width - 1) != 1
                                    && *(*map.at(j)).at(x + width - 1) != movable_object.id {
                                    collision_ids.append(*(*map.at(x + width - 1)).at(y));
                                }
                            }
                } else if direction == Move::UP.into() {
                    for i in x
                        ..(x
                            + width) {
                                if *(*map.at(y)).at(i) == 0 {
                                    collision_ids.append(0);
                                    break;
                                };

                                if *(*map.at(y)).at(i) != 1
                                    && *(*map.at(y)).at(i) != movable_object.id {
                                    collision_ids.append(*(*map.at(y)).at(i));
                                }
                            }
                } else if direction == Move::DOWN.into() {
                    for i in x
                        ..(x
                            + width) {
                                if *(*map.at(y + height - 1)).at(i) == 0 {
                                    collision_ids.append(0);
                                    break;
                                };

                                if *(*map.at(y + height - 1)).at(i) != 1
                                    && *(*map.at(y + height - 1)).at(i) != movable_object.id {
                                    collision_ids.append(*(*map.at(y + height - 1)).at(i));
                                }
                            }
                }
            };

            if (*collision_ids.at(0) != 0) {
                if delta_x == 1 {
                    x = x - 1
                } else if delta_x == 2 {
                    x = x + 1
                }
                if delta_y == 1 {
                    y = y - 1
                } else if delta_y == 2 {
                    y = y + 1
                }
            } else {
                x = 0;
                y = 0;
            };

            if x == movable_object.position.x && y == movable_object.position.y {
                panic_with_felt252('Object not moving');
            }

            let new_movable_object = MovableObjects {
                id: movable_object.id,
                name: movable_object.name,
                position: Position { x, y },
                size: movable_object.size,
                rotation: movable_object.rotation,
            };
            (new_movable_object, *collision_ids.at(0))
        }

        fn update_obstacles(ref self: ContractState, obstacles: Span<Obstacle>) -> Span<Obstacle> {
            let mut new_obstacles = array![];
            for obstacle in obstacles {
                if *obstacle.is_movable {
                    if *obstacle.is_interactable {
                        new_obstacles
                            .append(
                                Obstacle {
                                    id: *obstacle.id,
                                    name: *obstacle.name,
                                    position: *obstacle.position,
                                    size: *obstacle.size,
                                    rotation: *obstacle.rotation,
                                    is_movable: *obstacle.is_movable,
                                    is_interactable: false,
                                }
                            );
                    } else {
                        new_obstacles
                            .append(
                                Obstacle {
                                    id: *obstacle.id,
                                    name: *obstacle.name,
                                    position: *obstacle.position,
                                    size: *obstacle.size,
                                    rotation: *obstacle.rotation,
                                    is_movable: *obstacle.is_movable,
                                    is_interactable: true,
                                }
                            );
                    }
                } else {
                    new_obstacles.append(*obstacle);
                }
            };
            new_obstacles.span()
        }

        fn parse_map(self: @ContractState, map: PlayerProgress) -> Span<Span<u32>> {
            let mut parsed_map = ArrayTrait::<Span<u32>>::new();
            let mut i = 0;
            let mut j = 0;
            let new_parsed_map = loop {
                j = 0;
                if i == map.size.width + 2 {
                    break parsed_map.clone();
                }
                let mut column = ArrayTrait::<u32>::new();
                let new_column = loop {
                    if j == map.size.height + 2 {
                        break column.clone();
                    }
                    if j == 0 || i == 0 || j == map.size.height + 1 || i == map.size.width + 1 {
                        column.append(0);
                    } else {
                        let mut is_hash_obj = false;
                        for obj in map
                            .movable_objects {
                                if *obj.position.x != 0
                                    && *obj.position.y != 0
                                    && i >= *obj.position.y
                                    && i < *obj.position.y
                                    + *obj.size.height
                                        && j >= *obj.position.x
                                        && j < *obj.position.x
                                    + *obj.size.width {
                                    column.append(*obj.id);
                                    is_hash_obj = true;
                                    break;
                                }
                            };

                        if !is_hash_obj {
                            for obj in map
                                .obstacles {
                                    if i >= *obj.position.y && i < *obj.position.y
                                        + *obj.size.height
                                            && j >= *obj.position.x
                                            && j < *obj.position.x
                                        + *obj.size.width {
                                        column.append(*obj.id);
                                        is_hash_obj = true;
                                        break;
                                    }
                                };
                        }

                        if !is_hash_obj {
                            column.append(1);
                        }
                    }
                    j += 1;
                };

                parsed_map.append(new_column.span());
                i += 1;
            };

            new_parsed_map.span()
        }

        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"gridlock")
        }
    }
}
