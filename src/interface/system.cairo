use starknet::ContractAddress;
use gridlock::models::map::{Map, Size, MovableObjects, Obstacle};
use gridlock::models::player::Player;

#[starknet::interface]
trait IGridLockImpl<TState> {
    fn initialize(ref self: TState, owner: ContractAddress);
    fn update_map(
        ref self: TState,
        level: u32,
        size: Size,
        movable_objects: Span<MovableObjects>,
        obstacles: Span<Obstacle>,
    );
    fn start_new_game(ref self: TState);
    fn move(ref self: TState, object_id: u32, direction: felt252);
    fn pause(ref self: TState);
    fn unpause(ref self: TState);
    fn get_map(self: @TState, level: u32) -> Map;
    fn get_player_progress_map(self: @TState, address: ContractAddress) -> Span<Span<u32>>;
    fn get_player_progress_map_index(
        self: @TState, address: ContractAddress, x: u32, y: u32
    ) -> u32;
    fn get_player_data(self: @TState, address: ContractAddress) -> Player;
}
