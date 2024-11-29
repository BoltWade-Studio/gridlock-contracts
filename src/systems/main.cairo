#[dojo::contract]
mod GridLock {
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use gridlock::interface::system::IGridLockImpl;
    use gridlock::models::player::{Player, Move, PlayerProgress};
    use gridlock::models::map::{Map, MovableObjects, Obstacle, Size};
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
            movable_objects: Array<MovableObjects>,
            obstacles: Array<Obstacle>,
        ) {
            self.assert_only_owner();
            self.assert_initialized();
            assert(level > 0, 'Level must be greater than 0');
            assert(size.width > 0 && size.height > 0, 'Invalid size');
            assert!(movable_objects.len() > 0, "Movable objects must be greater than 0");

            for movable_object in movable_objects
                .span() {
                    assert(*movable_object.id > 0, 'Invalid id');
                    assert(*movable_object.position.x < size.width, 'Invalid position');
                    assert(*movable_object.position.y < size.height, 'Invalid position');
                    assert(
                        *movable_object.size.width > 0 && *movable_object.size.height > 0,
                        'Invalid size'
                    );
                    assert(*movable_object.rotation < 360, 'Invalid rotation');
                };

            for obstacle in obstacles
                .span() {
                    assert(*obstacle.id > 0, 'Invalid id');
                    assert(*obstacle.position.x < size.width, 'Invalid position');
                    assert(*obstacle.position.y < size.height, 'Invalid position');
                    assert(*obstacle.size.width > 0 && *obstacle.size.height > 0, 'Invalid size');
                    assert(*obstacle.rotation < 360, 'Invalid rotation');
                };

            let map = Map { level, size, movable_objects, obstacles, };

            let mut world = self.world_default();
            world.write_model(@map)
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

        fn move(ref self: ContractState, direction: felt252) {}

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

        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"gridlock")
        }
    }
}
