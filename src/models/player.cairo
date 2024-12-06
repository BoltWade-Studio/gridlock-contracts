use starknet::ContractAddress;
use gridlock::models::map::{Size, MovableObjects, Obstacle};

#[derive(Drop, Copy, Serde)]
#[dojo::model]
pub struct Player {
    #[key]
    pub address: ContractAddress,
    pub progress: PlayerProgress,
    pub point: u256
}

#[derive(Drop, Copy, Serde, Introspect)]
pub struct PlayerProgress {
    pub level: u32,
    pub size: Size,
    pub movable_objects: Span<MovableObjects>,
    pub obstacles: Span<Obstacle>,
}

#[derive(Drop, Copy, Serde, PartialEq)]
pub enum Move {
    UP,
    DOWN,
    LEFT,
    RIGHT,
}

impl MoveTypeFelt252 of Into<Move, felt252> {
    fn into(self: Move) -> felt252 {
        match self {
            Move::UP => 'up',
            Move::DOWN => 'down',
            Move::LEFT => 'left',
            Move::RIGHT => 'right',
        }
    }
}
