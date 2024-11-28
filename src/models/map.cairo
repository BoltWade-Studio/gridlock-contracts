#[derive(Drop, Serde, Introspect)]
#[dojo::model]
pub struct Map {
    #[key]
    pub level: u32,
    pub size: Size,
    pub movable_objects: Array<u32>,
    pub obstacles: Array<u32>,
}


#[derive(Drop, Copy, Serde, Introspect)]
pub struct MovableObjects {
    pub id: u32,
    pub position: Position,
    pub size: Size,
    pub rotation: u32,
}

#[derive(Drop, Copy, Serde, Introspect)]
pub struct Obstacle {
    pub id: u32,
    pub position: Position,
    pub size: Size,
    pub rotation: u32,
    pub is_movable: bool,
    pub is_interactable: bool,
}

#[derive(Drop, Copy, Serde, Introspect)]
pub struct Size {
    pub width: u32,
    pub height: u32,
}

#[derive(Drop, Copy, Serde, Introspect)]
pub struct Position {
    pub x: u32,
    pub y: u32,
}
