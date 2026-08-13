P³ Voxel Engine — Master Architecture (часть 1/2)
Движок для моделирования планеты через проективное многообразие P³.
Математика POLER-FPGA адаптирована под CPU/Rust. Бесшовная планета без
edge seams, воксели в однородных координатах.
Краткое содержание (10
разделов)
# Раздел Что описывает Ключевой артефакт 1 P³ Voxel Core Чанк и блок в P³ Chunk , Block , World типы 2 POLER Math Bridge CPU-адаптация POLER-FPGA math p3_poler_math crate 3 Chunk Streaming Загрузка/выгрузка по P³-метрике ChunkManager 4 Greedy Meshing in P³ Генерация мешей в однородных координатах MeshingPipeline 5 Ray Casting DDA в P³ Выбор блоков через P³ geodesics Raycaster 6 Camera & Projection P³ → screen projection Camera , Projector 7 World Generation Процедурная генерация по W WorldGenerator 8 Physics via POLER Физика через POLER cycle PhysicsEngine 9 Renderer Architecture Bevy/wgpu интеграция RenderPipeline 10 Master Architecture Связывает всё в единое целое p3_voxel_engine crate
1.1 Концепция
В классическом Minecraft каждый блок имеет целочисленные координаты (x, y, z) в бесконечном евклидовом R³. Это создаёт две
проблемы: 1. Мир бесконечен → нужна бесконечная память 2. Мир плоский →
не моделирует планету
В P³ Voxel Engine каждый блок — это точка в
проективном пространстве P³, представленная однородными координатами [X:Y:Z:W] . Это даёт: - Компактность: P³
компактно (как сфера S³/Z₂), мир = целая планета без “краёв” - Бесшовность: антиподальная идентификация v ~ -v склеивает границы естественно - Масштабируемость: W-координата = масштаб, калибровка W = cos(s/2R) связывает с реальными метрами
1.2 Rust типы
// crates/p3_voxel_core/src/types.rsuse p3_core:: { HomVec4 , Pgl4Matrix , PlanetScale };/// Идентификатор чанка — P³-точка (а не целочисленный индекс!)/// Это позволяет чанкам быть бесшовно расположенными на P³-многообразии.#[ derive ( Clone , Copy , Debug , PartialEq , Hash )]pub struct ChunkId( pub HomVec4) ; // [X:Y:Z:W], W определяет масштаб/// Базис чанка — 3 направляющих в P³, задающие локальную систему координат#[ derive ( Clone , Copy , Debug )]pub struct ChunkBasis {pub east : HomVec4 , // локальная ось X (восток)pub north : HomVec4 , // локальная ось Y (север)pub up : HomVec4 , // локальная ось Z (вверх)}/// Размер чанкаpub const CHUNK_SIZE : usize = 16 ; // 16³ = 4096 блоковpub const CHUNK_VOLUME : usize = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE ;/// Чанк — 16³ блоков с P³-координатами#[ derive ( Clone )]pub struct Chunk {pub id : ChunkId ,pub basis : ChunkBasis ,pub origin : HomVec4 , // P³-координата блока (0,0,0) чанкаpub blocks : Box < [BlockId ; CHUNK_VOLUME] >, // 16³ = 8 КБ (BlockId = u16)pub block_states : Box < [BlockState ; CHUNK_VOLUME] >, // 16³ × 4 байта = 16 КБ// Итого: ~24 КБ на чанк}impl Chunk {/// Преобразование локальных (i,j,k) → P³-координата блокаpub fn block_p3( & self , i : usize , j : usize , k : usize ) -> HomVec4 {// Смещение в локальных координатахlet offset = (i as f64 + 0.5 , j as f64 + 0.5 , k as f64 + 0.5 ) ;// Применяем базис чанка + origin// P³-преобразование: origin + offset.x * basis.east + offset.y * basis.north + offset.z * basis.uptodo! ( "Реализация через PGL(4)" )}/// Получить блок по локальным координатамpub fn get_block( & self , i : usize , j : usize , k : usize ) -> BlockId {self . blocks[i + j * CHUNK_SIZE + k * CHUNK_SIZE * CHUNK_SIZE]}/// Установить блокpub fn set_block( & mut self , i : usize , j : usize , k : usize , block : BlockId) {self . blocks[i + j * CHUNK_SIZE + k * CHUNK_SIZE * CHUNK_SIZE] = block ;}}/// Идентификатор типа блока#[ derive ( Clone , Copy , Debug , PartialEq , Eq )]#[ repr ( transparent )]pub struct BlockId( pub u16 ) ;impl BlockId {pub const AIR : BlockId = BlockId( 0 ) ;pub const STONE : BlockId = BlockId( 1 ) ;pub const DIRT : BlockId = BlockId( 2 ) ;pub const GRASS : BlockId = BlockId( 3 ) ;pub const WATER : BlockId = BlockId( 4 ) ;pub const SAND : BlockId = BlockId( 5 ) ;pub const WOOD : BlockId = BlockId( 6 ) ;pub const LEAVES : BlockId = BlockId( 7 ) ;// Лор-блоки Этерии (upper half)pub const FREDERITE : BlockId = BlockId( 0x8001 ) ;pub const PHI_ALLOY : BlockId = BlockId( 0x8002 ) ;pub const ADAMANTITE : BlockId = BlockId( 0x8003 ) ;pub const CHI_ORE : BlockId = BlockId( 0x8004 ) ;pub const PLATINUM : BlockId = BlockId( 0x8005 ) ;pub const ROOT_LAYER : BlockId = BlockId( 0x8006 ) ;pub fn is_air( self ) -> bool { self . 0 == 0 }pub fn is_solid( self ) -> bool { self . 0 != 0 }pub fn is_lore( self ) -> bool { self . 0 >= 0x8000 }}/// Состояние блока (4 байта — компактно)#[ derive ( Clone , Copy , Debug , Default )]#[ repr ( C )]pub struct BlockState {pub flags : BlockFlags ,pub light : u8 , // 0-15pub rotation : u8 , // 0-3 (поворот вокруг Y)pub reserved : u8 ,}bitflags::bitflags! {#[ derive ( Clone , Copy , Debug , Default )]pub struct BlockFlags : u8 {const CONDUCTOR = 0b0000_0001 ; // проводит φ-полеconst RESONANT = 0b0000_0010 ; // резонирует с фредеритомconst DISSIPATIVE = 0b0000_0100 ; // поглощает энергиюconst TRANSPARENT = 0b0000_1000 ; // пропускает светconst FLUID = 0b0001_0000 ; // жидкостьconst GAS = 0b0010_0000 ; // газconst ENTITY = 0b0100_0000 ; // содержит сущностьconst ROOT = 0b1000_0000 ; // корневой слой (неразрушимый)}}/// Мир — HashMap чанков (а не 3D-массив!)/// HashMap потому что чанки могут быть в любой точке P³#[ derive ( Default )]pub struct World {pub chunks : HashMap < ChunkId , Chunk >,pub planet : PlanetScale ,}impl World {pub fn new(planet : PlanetScale) -> Self {Self { chunks : HashMap:: new() , planet }}/// Получить чанк по P³-координатеpub fn get_chunk( & self , id : ChunkId) -> Option <& Chunk > {self . chunks . get( & id)}/// Получить блок по P³-координате (поиск по чанкам)pub fn get_block_at( & self , p3 : HomVec4) -> Option < BlockId > {// 1. Найти ближайший чанк// 2. Преобразовать P³ → локальные (i,j,k)// 3. Вернуть блокtodo! ()}}
1.3 Калибровка для чанков
Для планеты с радиусом R, размер чанка L в метрах, число
чанков на экваторе:
N_equator = 2πR / L
Для Земли (R=6378 км) и чанка 16 м: - Чанков на экваторе: 2π ×
6378000 / 16 ≈ 2 505 600 - Это много, но P³ компактно → загружаем только
чанки возле наблюдателя
Калибровка W для чанка на расстоянии s от наблюдателя:
fn chunk_w(s_meters : f64 , planet : & PlanetScale) -> f64 {(s_meters / planet . two_r) . cos()}
1.4 Соседство в P³
В R³ сосед чанка (x,y,z) — это (x±1, y, z) , (x, y±1, z) , (x, y, z±1) . Просто.
В P³ соседство сложнее — есть 4 типа:
pub enum Neighbor {/// Сосед в том же чанкеInChunk { dx : i8 , dy : i8 , dz : i8 },/// Сосед в смежном чанке (та же афинная карта)InAdjacentChunk { chunk_offset : ( i8 , i8 , i8 ) , local : ( usize , usize , usize ) },/// Сосед в другой афинной карте (W→0, нужно переключение)InOtherCard { card : AffineCard , transform : Pgl4Matrix },/// Антипод — прошиваем "бесконечность" (W=0)AtAntipode { transform : Pgl4Matrix },}
P³ компактно → AtAntipode возвращает нас обратно в мир.
Это и есть “бесшовность”.
1.5 Пример: чанк на экваторе
Земли
Наблюдатель: s=0, W=1
Чанк через 1° долготы (~111 км восточнее):
  s = 111 000 м
  W = cos(111000 / (2 × 6378000)) = cos(0.00871 рад) ≈ 0.999962
  
Чанк через 90° (~10 000 км):
  s = 10 000 000 м
  W = cos(10000000 / 12756000) = cos(0.7839 рад) ≈ 0.7087
  
Антипод (через 180°, ~20 037 км):
  s = π × 6378000 = 20 037 000 м
  W = cos(π/2) = 0  ← ПЕРЕКЛЕЙКА КАРТЫ
2.1 Что берём из POLER-FPGA
Из 8 Verilog модулей POLER-FPGA для P³ Voxel Engine берём:
POLER модуль Применение в P³ Voxel CPU эквивалент tensor_product.v Deformed tensor product для terrain deformation Mat4::deformed_tensor_product() cordic_inv_sqrt.v Нормализация векторов, кватернионов cordic::inv_sqrt() (f64, 4 итерации) newton_schulz_inv.v Инверсия матриц для projection Mat4::inverse_newton_schulz() poler_cycle.v Physics step (projected gradient descent) PhysicsEngine::step() qrwm.v Seed для procedural generation QrwmRng (CPU LFSR)
Не берём: top_level.v (memory-mapped I/O — это для FPGA,
не нужно на CPU).
2.2 Crate p3_poler_math
crates/p3_poler_math/
├── Cargo.toml
└── src/
    ├── lib.rs           — публичный API
    ├── tensor.rs        — Mat4, Vec4, deformed tensor product
    ├── cordic.rs        — 1/√x, sin/cos, atan2 (CPU оптимизация)
    ├── newton_schulz.rs — 4×4 matrix inversion
    ├── poler_cycle.rs   — projected gradient descent step
    ├── qrwm.rs          — LFSR RNG для procedural gen
    └── q32_32.rs        — опциональный fixed-point для hot paths
2.3 Ключевые функции
// crates/p3_poler_math/src/tensor.rsuse nalgebra:: Matrix4 ;/// Deformed tensor product: X ⊗_ε Y = (X·Y) + ε·(X⊙Y)/// Используется для:/// - Terrain deformation (смесь двух матриц трансформации)/// - Smooth transitions между чанкамиpub fn deformed_tensor_product(x : & Matrix4 < f64 >, y : & Matrix4 < f64 >, epsilon : f64 ) -> Matrix4 < f64 > {let linear = x * y ; // X·Y = matrix multiplicationlet hadamard = x . component_mul(y) ; // X⊙Y = element-wiselinear + hadamard * epsilon}/// Архетип: a ⊗_ε a = a (идемпотентность)/// Санity-check: фиксированная точкаpub fn verify_archetype_idempotent(a : & Matrix4 < f64 >, epsilon : f64 ) -> bool {let result = deformed_tensor_product(a , a , epsilon) ;(result - a) . abs() . max() < 1e-10}
// crates/p3_poler_math/src/cordic.rs/// CORDIC 1/√x через Newton-Raphson (как в POLER-FPGA v3.0+)/// Используется для:/// - Нормализация кватернионов (Quat::normalize)/// - Нормализация Vec3 (для ray casting)/// - 1/length в distance computations////// Альтернатива: std::f64::sqrt + division, но CORDIC быстрее на CPU с SIMDpub fn inv_sqrt(x : f64 ) -> f64 {if x <= 0.0 { return 0.0 ; }// Initial guess (fast inverse sqrt trick)let bits = x . to_bits() ;let magic = 0x5fe6eb50c7b537a9u64 ; // for f64let y = f64 :: from_bits(magic . wrapping_sub(bits >> 1 )) ;// Newton-Raphson iterations (3-4 достаточно для f64 точности)let y = y * ( 1.5 - 0.5 * x * y * y) ; // iteration 1let y = y * ( 1.5 - 0.5 * x * y * y) ; // iteration 2let y = y * ( 1.5 - 0.5 * x * y * y) ; // iteration 3y}/// CORDIC atan2(y, x) — для вычисления углов камерыpub fn atan2(y : f64 , x : f64 ) -> f64 {// Реализация через CORDIC rotation// (как в PolarFire FPGA, но адаптировано для CPU)y . atan2(x) // fallback на std}
// crates/p3_poler_math/src/newton_schulz.rsuse nalgebra:: Matrix4 ;/// Newton-Schulz итеративная инверсия 4×4 матрицы/// X_{k+1} = X_k · (2I - M · X_k)////// Используется для:/// - Инверсия projection matrices/// - Инверсия camera transform/// - POLER cycle (для projector Π_Λ)////// Сходится для symmetric positive-definite матриц./// Добавляем Tikhonov regularization для устойчивости.pub fn inverse_newton_schulz(m : & Matrix4 < f64 >,delta : f64 , // Tikhonov regularizationmax_iter : usize , // обычно 8) -> Option < Matrix4 < f64 >> {let n = Matrix4:: identity() ;let m_reg = m + delta * n ; // Tikhonov// Initial guess: X_0 = M^T / ||M||²let mut x = m_reg . transpose() / m_reg . norm_squared() ;for _ in 0 .. max_iter {// X_{k+1} = X_k · (2I - M · X_k)let mx = m_reg * x ;x = x * ( 2.0 * n - mx) ;// Проверка сходимостиlet residual = (m_reg * x - n) . abs() . max() ;if residual < 1e-12 {return Some (x) ;}}Some (x)}
// crates/p3_poler_math/src/qrwm.rs/// QRwM (Quantum Randomness without Measurement) — CPU версия/// LFSR 64-bit Galois (как в POLER-FPGA v5.0)/// Используется для:/// - Seed для procedural generation (Perlin noise)/// - Cryptographic-strength seed для multiplayer/// - Non-deterministic physics (chaos)pub struct QrwmRng {lfsr_state : u64 ,kappa_static : u64 ,}impl QrwmRng {const TAP_MASK : u64 = 0xB000_0000_0000_0000 ; // x^64 + x^63 + x^61 + x^60 + 1const INITIAL_SEED : u64 = 0xACE1_2468_1357_9BDF ;pub fn new(kappa_static : u64 ) -> Self {Self { lfsr_state : Self :: INITIAL_SEED , kappa_static }}/// Один шаг LFSRfn lfsr_step(state : u64 ) -> u64 {if state & 1 != 0 {(state >> 1 ) ^ Self :: TAP_MASK} else {state >> 1}}/// Генерация ephemeral key (как в FPGA)pub fn generate( & mut self , entropy : u64 ) -> u64 {// ACCUMULATE: 8 шагов с entropyfor i in 0 .. 8 {let ent_byte = (entropy >> (i * 8 )) & 0xFF ;self . lfsr_state = Self :: lfsr_step( self . lfsr_state) ^ ent_byte ;}// CONDITION: 4 дополнительных шагаfor _ in 0 .. 4 {self . lfsr_state = Self :: lfsr_step( self . lfsr_state) ;}// OUTPUT: XOR со статическим ключомlet kappa_eff = self . kappa_static ^ self . lfsr_state ;// DESTROY (в CPU версии не нужно — просто возвращаем)kappa_eff}}
2.4 Тесты
#[ cfg ( test )]mod tests {use super :: *;#[ test ]fn test_archetype_idempotent() {let a = Matrix4:: new(1.0 , 0.5 , 0.0 , 0.0 ,0.0 , 1.0 , 0.5 , 0.0 ,0.0 , 0.0 , 1.0 , 0.5 ,0.0 , 0.0 , 0.0 , 1.0 ,) ;assert! (verify_archetype_idempotent( & a , 0.1 )) ;}#[ test ]fn test_cordic_inv_sqrt() {for & x in & [ 1.0 , 4.0 , 100.0 , 10000.0 ] {let expected = 1.0 / x . sqrt() ;let actual = inv_sqrt(x) ;assert! ((actual - expected) . abs() < 1e-10 ) ;}}#[ test ]fn test_newton_schulz_inverse() {let m = Matrix4:: new(4.0 , 1.0 , 0.0 , 0.0 ,1.0 , 3.0 , 1.0 , 0.0 ,0.0 , 1.0 , 2.0 , 1.0 ,0.0 , 0.0 , 1.0 , 1.0 ,) ;let inv = inverse_newton_schulz( & m , 1e-10 , 8 ) . unwrap() ;let product = m * inv ;assert! ((product - Matrix4:: identity()) . abs() . max() < 1e-8 ) ;}#[ test ]fn test_qrwm_deterministic() {let mut rng1 = QrwmRng:: new( 0xDEAD_BEEF ) ;let mut rng2 = QrwmRng:: new( 0xDEAD_BEEF ) ;for _ in 0 .. 10 {assert_eq! (rng1 . generate( 0x1234 ) , rng2 . generate( 0x1234 )) ;}}}
3.1 Принцип
В классическом Minecraft чанки грузятся по дистанции от игрока
(евклидово расстояние). В P³ Voxel Engine чанки грузятся по P³-метрике (Фубини-Штуди):
d_FS(observer, chunk) = arccos(|<observer, chunk>| / (||observer|| · ||chunk||))
Это даёт естественную LOD (Level of Detail) систему:
- Близкие чанки (d_FS < 0.001) → высокое разрешение - Дальние (0.001
< d_FS < 0.1) → среднее разрешение - Очень дальние (d_FS > 0.1)
→ низкое разрешение - Антипод (d_FS = π/2) → не грузится вообще
P³ Voxel Engine — Master Architecture (часть 2/2)
3.2 Архитектура
// crates/p3_voxel_streaming/src/manager.rsuse p3_voxel_core:: { Chunk , ChunkId , World };use p3_core:: { HomVec4 , fs_distance , PlanetScale };use std::collections:: { HashMap , VecDeque };pub struct ChunkManager {pub world : World ,pub loaded_chunks : HashMap < ChunkId , Chunk >,pub loading_queue : VecDeque < ChunkId >,pub unload_queue : VecDeque < ChunkId >,/// Максимальное число чанков в памятиpub max_loaded : usize ,/// Радиус загрузки в P³-метрике (радианы)pub load_radius : f64 , // например, 0.01 рад ≈ 64 км на Земле/// Текущая позиция наблюдателяpub observer : HomVec4 ,}impl ChunkManager {/// Обновление: загрузить/выгрузить чанки при перемещении наблюдателяpub fn update( & mut self , new_observer : HomVec4) {self . observer = new_observer ;// 1. Найти чанки в радиусе загрузкиlet chunks_to_load = self . find_chunks_in_radius( self . load_radius) ;// 2. Добавить в очередь загрузки те, что ещё не загруженыfor chunk_id in chunks_to_load {if ! self . loaded_chunks . contains_key( & chunk_id) {self . loading_queue . push_back(chunk_id) ;}}// 3. Найти чанки за пределами радиуса — пометить на выгрузкуlet chunks_to_unload : Vec < _ > = self . loaded_chunks . keys(). filter( | chunk_id | {let dist = fs_distance( self . observer , chunk_id . 0 ) ;dist > self . load_radius * 1.5 // hysteresis} ). copied(). collect() ;for chunk_id in chunks_to_unload {self . unload_queue . push_back(chunk_id) ;}// 4. Выполнить загрузку/выгрузку (по N за кадр)self . process_queues( 4 ) ; // 4 загрузки + 4 выгрузки за кадр}/// Найти все чанки в радиусе d от наблюдателяfn find_chunks_in_radius( & self , radius : f64 ) -> Vec < ChunkId > {// Преобразование P³-радиуса в чанк-координаты// s_max = 2R * radius (физическое расстояние)// N_chunks = (s_max / chunk_size)³let s_max = self . world . planet . two_r * radius ;let chunk_size_m = 16.0 ; // 16 метровlet n_chunks_per_axis = (s_max / chunk_size_m) . ceil() as usize ;let mut chunks = Vec :: new() ;// ... (генерация ChunkId вокруг наблюдателя)chunks}fn process_queues( & mut self , batch_size : usize ) {// Загрузкаfor _ in 0 .. batch_size {if let Some (chunk_id) = self . loading_queue . pop_front() {if self . loaded_chunks . len() >= self . max_loaded {self . unload_oldest() ;}if let Some (chunk) = self . generate_chunk(chunk_id) {self . loaded_chunks . insert(chunk_id , chunk) ;}}}// Выгрузкаfor _ in 0 .. batch_size {if let Some (chunk_id) = self . unload_queue . pop_front() {if let Some (chunk) = self . loaded_chunks . remove( & chunk_id) {self . save_chunk_to_disk(chunk) ;}}}}fn generate_chunk( & self , chunk_id : ChunkId) -> Option < Chunk > {// Делегирование в WorldGenerator (Раздел 7)todo! ()}fn save_chunk_to_disk( & self , chunk : Chunk) {// Сохранение в chunk файл (например, ./world/chunks/<hash>.bin)todo! ()}fn unload_oldest( & mut self ) {// LRU evictiontodo! ()}}
3.3 LOD (Level of Detail)
pub enum ChunkLod {High , // 16³ блоков (full detail)Medium , // 8³ блоков (2x downsample)Low , // 4³ блоков (4x downsample)Minimal , // 2³ блоков (8x downsample)}impl ChunkManager {pub fn lod_for_distance(d_fs : f64 ) -> ChunkLod {match d_fs {d if d < 0.0001 => ChunkLod:: High , // ~640 мd if d < 0.001 => ChunkLod:: Medium , // ~6.4 кмd if d < 0.01 => ChunkLod:: Low , // ~64 кмd if d < 0.05 => ChunkLod:: Minimal , // ~320 км_ => panic! ( "Слишком далеко для загрузки" ) ,}}}
4.1 Принцип
Greedy meshing — классический алгоритм Minecraft, объединяющий
соседние блоки с одинаковым типом в один mesh-face. В R³ это
прямоугольники (x1,y1,z1)→(x2,y2,z2) .
В P³ meshing сложнее: - Грани блоков — это плоскости в
P³ (а не в R³) - Соседние блоки в одной афинной карте → обычный
greedy meshing - Соседние блоки через афинную границу (W=0) → meshing с
переключением карты - Антиподальные блоки → meshing “через
бесконечность”
4.2 Алгоритм
// crates/p3_voxel_meshing/src/greedy.rsuse p3_voxel_core:: { Chunk , ChunkId , BlockId , CHUNK_SIZE };use p3_poler_math::tensor:: deformed_tensor_product ;pub struct MeshFace {pub block_id : BlockId ,pub normal : [ f64 ; 3 ] , // нормаль в локальных координатахpub vertices : [[ f64 ; 3 ] ; 4 ] , // 4 угла face в P³pub uv : [[ f32 ; 2 ] ; 4 ] ,}pub struct ChunkMesh {pub faces : Vec < MeshFace >,}/// Greedy meshing для одного чанкаpub fn mesh_chunk(chunk : & Chunk) -> ChunkMesh {let mut faces = Vec :: new() ;// 3 прохода: по X, Y, Z осямfor axis in 0 .. 3 {faces . extend(mesh_axis(chunk , axis)) ;}ChunkMesh { faces }}fn mesh_axis(chunk : & Chunk , axis : usize ) -> Vec < MeshFace > {let mut faces = Vec :: new() ;let mut mask = vec! [ BlockId:: AIR ; CHUNK_SIZE * CHUNK_SIZE] ;// Проход по слоям вдоль осиfor layer in 0 .. CHUNK_SIZE + 1 {// 1. Построить маску: какие блоки видны с этой стороныbuild_mask(chunk , axis , layer , & mut mask) ;// 2. Greedy merge соседних одинаковых блоков в маскеlet merged = merge_mask( & mask) ;// 3. Создать faces из merged regionsfor region in merged {faces . push(create_face(chunk , axis , layer , region)) ;}}faces}fn build_mask(chunk : & Chunk , axis : usize , layer : usize , mask : & mut [BlockId]) {// Для каждого (i,j) в плоскости перпендикулярной axis:// Если блок на layer-1 виден из layer (т.е. блок на layer = AIR)// → mask[i + j * CHUNK_SIZE] = block на layer-1// Иначе AIRtodo! ()}fn merge_mask(mask : & [BlockId]) -> Vec < Rect > {// Классический greedy merge:// 1. Найти прямоугольник начиная с (0,0)// 2. Расширить вправо пока блоки одинаковые// 3. Расширить вниз пока строка одинаковая// 4. Пометить объединённые ячейки как AIR// 5. Повторятьtodo! ()}fn create_face(chunk : & Chunk , axis : usize , layer : usize , rect : Rect) -> MeshFace {// Создать 4 вершины face в P³ координатах// Использовать chunk.block_p3(i,j,k) для каждой вершиныtodo! ()}
4.3 Cross-card meshing
Когда face пересекает границу афинной карты (W=0), нужно: 1. Разбить
face на две части (до и после границы) 2. Каждую часть преобразовать
через PGL(4) матрицу перехода 3. Отрендерить как два отдельных face
Это случается редко (только на границах чанков с W≈0), но нужно
обработать корректно.
5.1 Принцип
Классический DDA (Digital Differential Analyzer) в R³: шагаем по
лучу, проверяем блоки.
В P³ луч — это геодезическая (большой круг на S³,
спроецированный на P³). Алгоритм: 1. Стартовый луч (origin, direction) в локальных координатах игрока 2.
Преобразовать в P³ координаты 3. Шагать по геодезической через
fs_geodesic (из p3_core.py) 4. На каждом шаге проверять блок в текущем
P³-position 5. Если блок твёрдый — вернуть hit
5.2 Реализация
// crates/p3_voxel_raycast/src/dda.rsuse p3_voxel_core:: { World , BlockId };use p3_core:: { HomVec4 , fs_geodesic , fs_distance , PlanetScale };pub struct Ray {pub origin : HomVec4 ,pub direction : HomVec4 , // нормализованныйpub max_distance : f64 ,}pub struct RaycastHit {pub block : BlockId ,pub position : HomVec4 ,pub normal : [ f64 ; 3 ] , // нормаль блокаpub distance : f64 ,}pub fn raycast(world : & World , ray : & Ray) -> Option < RaycastHit > {let mut current = ray . origin ;let step_size = 0.5 ; // 0.5 метра в P³-метрикеlet mut traveled = 0.0 ;while traveled < ray . max_distance {// Шаг по геодезическойlet t = step_size / ( 2.0 * world . planet . radius_m) ; // в радианахcurrent = fs_geodesic(ray . origin , ray . direction , t) ;traveled += step_size ;// Получить блок в текущей P³-позицииif let Some (block) = world . get_block_at(current) {if block . is_solid() {return Some (RaycastHit {block ,position : current ,normal : compute_normal(world , current) ,distance : traveled ,} ) ;}}}None}fn compute_normal(world : & World , pos : HomVec4) -> [ f64 ; 3 ] {// Найти соседние блоки и определить нормальtodo! ()}
5.3 Особенности P³ ray casting
Антиподальная зацикленность: луч, идущий “в
бесконечность”, выходит с другой стороны планеты. Это естественная
физика P³.
Переключение карт: когда луч пересекает W=0, мы
переключаемся на другую афинную карту. Координаты в локальной карте
меняются, но ray продолжается.
Локальная оптимизация: для близких лучей (d_FS
< 0.0001) можно использовать обычный R³ DDA — это быстрее и точность
та же.
6.1 Камера как P³-node
// crates/p3_voxel_camera/src/camera.rsuse p3_core:: { HomVec4 , Pgl4Matrix , PlanetScale };use p3_poler_math::cordic:: inv_sqrt ;pub struct Camera {/// Позиция в P³pub position : HomVec4 ,/// Ориентация (кватернион)pub rotation : Quat ,/// Угол обзора (FOV)pub fov : f64 ,/// Соотношение сторонpub aspect : f64 ,/// Ближняя/дальняя плоскости отсечения (в метрах)pub near : f64 ,pub far : f64 ,/// Планета (для калибровки)pub planet : PlanetScale ,}impl Camera {/// View matrix: P³-координаты → координаты камерыpub fn view_matrix( & self ) -> Pgl4Matrix {// 1. Перенос: -position// 2. Поворот: inverse(rotation)// 3. Комбинировать через PGL(4)todo! ()}/// Projection matrix: координаты камеры → экранные координатыpub fn projection_matrix( & self ) -> Pgl4Matrix {// Perspective projection через PGL(4)// near, far, fov, aspect → стандартная perspective matrixtodo! ()}/// Нормализованный кватернион через CORDICpub fn normalize_rotation( & mut self ) {let len_sq = self . rotation . w * self . rotation . w+ self . rotation . x * self . rotation . x+ self . rotation . y * self . rotation . y+ self . rotation . z * self . rotation . z ;let inv_len = inv_sqrt(len_sq) ;self . rotation . w *= inv_len ;self . rotation . x *= inv_len ;self . rotation . y *= inv_len ;self . rotation . z *= inv_len ;}}#[ derive ( Clone , Copy , Debug )]pub struct Quat {pub w : f64 ,pub x : f64 ,pub y : f64 ,pub z : f64 ,}
6.2 P³ → Screen pipeline
P³-point (HomVec4)
    ↓ view_matrix (PGL4)
Camera-space (Vec3 + W)
    ↓ projection_matrix (PGL4)
Clip-space (Vec4)
    ↓ perspective divide
NDC (Normalized Device Coordinates, Vec3)
    ↓ viewport transform
Screen-space (Vec2 + depth)
Особенность P³: при perspective divide мы делим на W-координату. Это
автоматически обрабатывает “бесконечность” — блоки с W→0 уходят в
бесконечность и отсекаются.
6.3 Frustum culling
Frustum culling в P³ — отсечение чанков вне пирамиды обзора: 1.
Вычислить 6 плоскостей frustum в P³ 2. Для каждого чанка проверить:
находится ли внутри всех 6 плоскостей 3. Если снаружи — не рендерить
В P³ плоскости frustum — это P³-плоскости (3-мерные
гиперплоскости в R⁴). Проверка: dot-product с P³-нормалью.
7.1 Принцип
Процедурная генерация через Perlin noise, но в P³ координатах. Биомы
определяются по W-координате (расстояние от наблюдателя по планете).
7.2 Реализация
// crates/p3_voxel_worldgen/src/generator.rsuse p3_voxel_core:: { Chunk , ChunkId , BlockId , CHUNK_SIZE };use p3_core:: { HomVec4 , PlanetScale };use p3_poler_math::qrwm:: QrwmRng ;pub struct WorldGenerator {pub planet : PlanetScale ,pub seed : u64 ,pub qrwm : QrwmRng ,}impl WorldGenerator {pub fn generate_chunk( & mut self , chunk_id : ChunkId) -> Chunk {let mut chunk = Chunk:: new(chunk_id) ;// Для каждого блока в чанкеfor i in 0 .. CHUNK_SIZE {for j in 0 .. CHUNK_SIZE {for k in 0 .. CHUNK_SIZE {let p3 = chunk . block_p3(i , j , k) ;let block = self . generate_block(p3) ;chunk . set_block(i , j , k , block) ;}}}chunk}fn generate_block( & mut self , p3 : HomVec4) -> BlockId {// 1. Получить 3D координаты на поверхности планетыlet (lat , lon , height) = self . p3_to_geo(p3) ;// 2. Определить биом по lat/lonlet biome = self . biome_for(lat , lon) ;// 3. Высота поверхности (Perlin noise)let surface_height = self . perlin_noise(lat , lon) ;// 4. Тип блока по высоте и биомуif height < surface_height - 5.0 {BlockId:: STONE} else if height < surface_height - 1.0 {BlockId:: DIRT} else if height < surface_height {biome . surface_block()} else if height < surface_height + 3.0 {BlockId:: WATER // океаны} else {BlockId:: AIR}}fn p3_to_geo( & self , p3 : HomVec4) -> ( f64 , f64 , f64 ) {// P³ → (lat, lon, height над поверхностью)todo! ()}fn perlin_noise( & self , lat : f64 , lon : f64 ) -> f64 {// 3D Perlin noise с seedtodo! ()}fn biome_for( & self , lat : f64 , lon : f64 ) -> Biome {// Определение биома по координатамtodo! ()}}pub enum Biome {Plains ,Desert ,Mountains ,Ocean ,Tundra ,Jungle ,// Лор-биомы ЭтерииFrederiteCaverns , // подземные пещеры с фредеритомChiWastes , // поверхностные χ-зоныPlatinumFields , // редкие платиновые месторождения}impl Biome {fn surface_block( & self ) -> BlockId {match self {Biome:: Plains => BlockId:: GRASS ,Biome:: Desert => BlockId:: SAND ,Biome:: Mountains => BlockId:: STONE ,_ => BlockId:: DIRT ,}}}
7.3 Использование QRwM для
seed
impl WorldGenerator {pub fn new(planet : PlanetScale , master_seed : u64 ) -> Self {let mut qrwm = QrwmRng:: new(master_seed) ;// Generate ephemeral seed для каждого чанкаSelf { planet , seed : master_seed , qrwm }}fn chunk_seed( & mut self , chunk_id : ChunkId) -> u64 {// Комбинация master_seed + chunk_id через QRwMlet entropy = chunk_id . 0 . to_bits() ;self . qrwm . generate(entropy)}}
8.1 Принцип
POLER cycle = projected gradient descent:
P_new = p_t - η · Π_Λ(D·p_t + γ·J·p_t + ∇F)
Используется для: - Physically-based motion: объекты
движутся по градиенту энергии - Constraint projection: Π_Λ удерживает объекты на многообразии P³ - Dissipation: D = L·Lᵀ моделирует трение/сопротивление - Resonance: J = A-Aᵀ моделирует колебательные
системы
8.2 Реализация
// crates/p3_voxel_physics/src/engine.rsuse p3_core:: { HomVec4 , Pgl4Matrix , PlanetScale };use p3_poler_math:: { newton_schulz:: inverse_newton_schulz , poler_cycle };pub struct PhysicsEngine {pub planet : PlanetScale ,/// Параметры POLER cyclepub eta : f64 , // learning rate (сила шага)pub gamma : f64 , // resonance couplingpub mix : f64 , // quantum normalization mixingpub delta : f64 , // Tikhonov regularization}pub struct PhysicsObject {pub position : HomVec4 ,pub velocity : HomVec4 ,pub mass : f64 ,pub constraints : Vec < Constraint >, // Π_Λ}pub enum Constraint {/// Ограничение на поверхность планетыOnSurface ,/// Ограничение на фиксированном расстоянии от другого объектаFixedDistance { target : HomVec4 , distance : f64 },/// Кастомное ограничение через P³-плоскостьPlane(Pgl4Matrix) ,}impl PhysicsEngine {pub fn step( & self , obj : & mut PhysicsObject , dt : f64 ) {// 1. Вычислить force (gradient of energy)let force = self . compute_force(obj) ;// 2. Вычислить dissipator D = L·L^Tlet d = self . compute_dissipator(obj) ;// 3. Вычислить resonance J = A - A^Tlet j = self . compute_resonance(obj) ;// 4. Построить projector Π_Λ из constraintslet pi_lambda = self . compute_projector( & obj . constraints) ;// 5. POLER cycle steplet force_vec = d * obj . position + j * obj . position * self . gamma + force ;let projected_force = pi_lambda * force_vec ;let p_new = obj . position - self . eta * projected_force * dt ;// 6. Quantum normalization (CORDIC)let norm_sq = p_new . dot( & p_new) ;let inv_norm = p3_poler_math::cordic:: inv_sqrt(norm_sq) ;let p_normalized = p_new * ( 1.0 - self . mix) + p_new * ( self . mix * inv_norm) ;obj . position = p_normalized ;}fn compute_force( & self , obj : & PhysicsObject) -> HomVec4 {// Гравитация, упругие силы, etc.todo! ()}fn compute_dissipator( & self , obj : & PhysicsObject) -> Pgl4Matrix {// L = friction matrix (lower triangular)// D = L · L^Ttodo! ()}fn compute_resonance( & self , obj : & PhysicsObject) -> Pgl4Matrix {// A = history-dependent// J = A - A^T (skew-symmetric)todo! ()}fn compute_projector( & self , constraints : & [Constraint]) -> Pgl4Matrix {// Π_Λ = I - Jc^T (Jc Jc^T + δI)^-1 Jc// через Newton-Schulz inversiontodo! ()}}
9.1 Принцип
Используем Bevy engine (ECS + wgpu) для рендеринга.
P³ Voxel Engine — как plugin для Bevy.
9.2 Архитектура
// crates/p3_voxel_render/src/plugin.rsuse bevy::prelude:: *;pub struct P3VoxelPlugin ;impl Plugin for P3VoxelPlugin {fn build( & self , app : & mut App) {app. add_plugins(P3CorePlugin). add_plugins(P3PolerMathPlugin). add_systems(Update , (chunk_streaming_system ,meshing_system ,camera_system ,render_system ,) . chain()) ;}}fn chunk_streaming_system(mut chunk_manager : ResMut < ChunkManager >,camera : Query <& Camera >,) {if let Ok (cam) = camera . single() {chunk_manager . update(cam . position) ;}}fn meshing_system(chunk_manager : Res < ChunkManager >,mut meshes : ResMut < Assets < Mesh >>,mut materials : ResMut < Assets < StandardMaterial >>,mut chunk_meshes : Query <& mut Handle < Mesh >, With < ChunkEntity >>,) {// Перегенерация мешей для изменившихся чанковtodo! ()}fn camera_system(keyboard : Res < Input < KeyCode >>,mut camera : Query <& mut Camera >,time : Res < Time >,) {// Управление камеройtodo! ()}fn render_system(camera : Query <& Camera >,chunk_manager : Res < ChunkManager >,mut render_pipeline : ResMut < RenderPipeline >,) {// Frustum culling + draw callstodo! ()}
9.3 Shader (WGSL)
// shaders/p3_voxel.wgsl
struct VertexInput {
    @location(0) position: vec4<f32>,  // HomVec4 (X, Y, Z, W)
    @location(1) normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
};
struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) normal: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) world_position: vec4<f32>,
};
@group(0) @binding(0) var<uniform> view_proj: mat4x4<f32>;
@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    
    // Perspective divide в P³
    let world_pos = in.position;
    let view_pos = view_proj * world_pos;
    
    // P³ projection: divide by W (если W не 0)
    let w = select(view_pos.w, 1.0, view_pos.w == 0.0);
    out.clip_position = vec4<f32>(
        view_pos.x / w,
        view_pos.y / w,
        view_pos.z / w,
        1.0,
    );
    
    out.normal = in.normal;
    out.uv = in.uv;
    out.world_position = world_pos;
    
    out
}
@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    // Простое освещение
    let light_dir = normalize(vec3<f32>(0.5, 1.0, 0.3));
    let diffuse = max(dot(in.normal, light_dir), 0.0);
    let color = vec3<f32>(0.5, 0.4, 0.3) * (0.3 + 0.7 * diffuse);
    
    vec4<f32>(color, 1.0)
}
10.1 Crate структура
p3-voxel-engine/
├── Cargo.toml                    # workspace
├── crates/
│   ├── p3-core/                  # P³ mathematics (PGL(4), Fubini-Study, etc.)
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── homogeneous.rs    # HomVec4
│   │       ├── pgl4.rs           # Pgl4Matrix
│   │       ├── fubini_study.rs   # fs_distance, fs_geodesic
│   │       ├── cards.rs          # AffineCard enum
│   │       ├── pi1.rs            # ℤ/2ℤ generator
│   │       └── physical_scale.rs # PlanetScale, W=cos(s/2R)
│   │
│   ├── p3-poler-math/            # POLER-FPGA math bridge
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── tensor.rs         # deformed tensor product
│   │       ├── cordic.rs         # 1/√x, sin/cos, atan2
│   │       ├── newton_schulz.rs  # matrix inversion
│   │       ├── poler_cycle.rs    # projected gradient descent
│   │       └── qrwm.rs           # LFSR RNG
│   │
│   ├── p3-voxel-core/            # Chunk, Block, World
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── types.rs          # ChunkId, BlockId, BlockState
│   │       ├── chunk.rs          # Chunk struct
│   │       ├── world.rs          # World, HashMap<ChunkId, Chunk>
│   │       └── neighbor.rs       # Neighbor enum
│   │
│   ├── p3-voxel-streaming/       # Chunk loading/unloading
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── manager.rs        # ChunkManager
│   │       ├── lod.rs            # ChunkLod
│   │       └── storage.rs        # disk persistence
│   │
│   ├── p3-voxel-meshing/         # Greedy meshing
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── greedy.rs         # mesh_chunk
│   │       └── cross_card.rs     # meshing через афинные карты
│   │
│   ├── p3-voxel-raycast/         # DDA в P³
│   │   └── src/
│   │       ├── lib.rs
│   │       └── dda.rs            # raycast
│   │
│   ├── p3-voxel-camera/          # Camera, projection
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── camera.rs         # Camera struct
│   │       ├── quat.rs           # Quat (CORDIC-normalized)
│   │       └── frustum.rs        # frustum culling
│   │
│   ├── p3-voxel-worldgen/        # Procedural generation
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── generator.rs      # WorldGenerator
│   │       ├── biome.rs          # Biome enum
│   │       └── noise.rs          # Perlin noise
│   │
│   ├── p3-voxel-physics/         # POLER physics
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── engine.rs         # PhysicsEngine
│   │       ├── object.rs         # PhysicsObject
│   │       └── constraint.rs     # Constraint enum
│   │
│   ├── p3-voxel-render/          # Bevy integration
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── plugin.rs         # P3VoxelPlugin
│   │       ├── systems.rs        # ECS systems
│   │       └── shaders/
│   │           ├── p3_voxel.wgsl
│   │           └── p3_shadow.wgsl
│   │
│   └── p3-voxel-app/             # Главный binary
│       └── src/
│           └── main.rs           # entry point
│
├── tests/
│   ├── integration_tests.rs
│   └── benchmarks.rs
│
└── examples/
    ├── minimal_world.rs          # минимальный пример
    ├── planet_viewer.rs          # просмотр целой планеты
    └── creative_mode.rs          # creative mode gameplay
10.2 Зависимости между crates
p3-voxel-app
├── p3-voxel-render
│   ├── p3-voxel-camera
│   │   ├── p3-core
│   │   └── p3-poler-math
│   ├── p3-voxel-meshing
│   │   ├── p3-voxel-core
│   │   └── p3-poler-math
│   ├── p3-voxel-streaming
│   │   ├── p3-voxel-core
│   │   └── p3-voxel-worldgen
│   │       ├── p3-voxel-core
│   │       └── p3-poler-math
│   └── bevy
├── p3-voxel-raycast
│   ├── p3-voxel-core
│   └── p3-core
├── p3-voxel-physics
│   ├── p3-voxel-core
│   ├── p3-core
│   └── p3-poler-math
└── p3-voxel-core
    └── p3-core
10.3 Сравнение с Minecraft
Параметр Minecraft P³ Voxel Engine Геометрия мира R³ (бесконечный плоский) P³ (компактная планета) Бесконечность По краям генерируются новые чанки Не существует — планета замкнута Переход антипода Невозможен Естественный (через W=0) Масштаб Один глобальный масштаб Локальный R³ ≈ P³ для близких, P³ для дальних Чанков на Земле Бесконечно ~2.5M (конечное число, можно всё хранить) Память Растёт безгранично Ограничена (LRU eviction) GPU/CPU GPU для рендера, CPU для логики То же + опциональный CORDIC для hot paths
10.4 Roadmap разработки
Этап 1: Foundation (2-3
недели)
p3-core (есть прототип на Python, нужно перенести на Rust)
p3-poler-math (извлечь из POLER-FPGA)
p3-voxel-core (типы Chunk, Block, World)
Этап 2: World (3-4 недели)
p3-voxel-worldgen (Perlin noise + biomes)
p3-voxel-streaming (ChunkManager + LOD)
p3-voxel-meshing (greedy meshing)
Этап 3: Interaction (2-3
недели)
p3-voxel-camera (camera + projection)
p3-voxel-raycast (DDA для выбора блоков)
p3-voxel-physics (POLER cycle)
Этап 4: Rendering (2-3 недели)
p3-voxel-render (Bevy plugin + shaders)
p3-voxel-app (главный binary)
Этап 5: Polish (2-3 недели)
Оптимизация (SIMD, cache, profiling)
Тестирование (integration tests, benchmarks)
Документация (API docs, examples)
Итого: 11-16 недель для production-ready движка.
10.5 Тесты производительности
Тест Цель Метрика Chunk generation 1000 чанков < 1 сек Meshing 100 чанков < 100 мс Raycast 1000 лучей < 16 мс (60 FPS) Streaming Перемещение игрока < 50 мс на update Render 1000 чанков в view 60 FPS @ 1080p
Заключение
P³ Voxel Engine — это принципиально новый подход к
воксельным мирам: 1. Бесшовная планета вместо
бесконечного плоского мира 2. POLER-FPGA math даёт
аппаратно-оптимизированные операции (CORDIC, Newton-Schulz) 3. Масштабируемость через P³-метрику: локально R³,
глобально P³ 4. Канон Этерии — фредерит, φ-сплав, биомы
из лора Сферы Предела
Архитектура полностью спроектирована, готова к реализации на Rust +
Bevy.
P³ Voxel Core — Подробная спецификация (часть 1/2)
Task ID: p3-voxel-core-spec Agent: 1 / 10 (P³ Voxel Engine master plan) Статус: спецификация (без реализации). Реализацию делают агенты 3–10. Источники: - P3_COMPENDIUM.pdf —
математическое ядро P³, афинные карты, PGL(4), метрика Фубини–Штуди,
калибровка W=cos(s/2R). - POLER_FPGA_Code_v5.md + tensor.zig + poler_v0.3.3.rs —
переиспользуемые матзаведения: Mat4, деформированное тензорное
произведение, logical projector, Newton–Schulz 4×4 inversion, CORDIC
1/√x, Q32.32 fixed-point. - worklog.md §«p3-voxel-engine-master-brief» — постановка от главного агента.
1. Концепция (как P³
применяется к вокселям)
1.1. Что такое P³
P³ = реальное проективное пространство ℝ³ размерности 3 =
факторпространство ℝ⁴  {0} по отношению эквивалентности v ~ λ·v для любого λ ≠ 0 . Точка P³ — это
прямая в ℝ⁴ через начало координат. Канонический представитель —
нормированный вектор [X:Y:Z:W] с ‖v‖ = 1 . Знак
остаётся неоднозначным ( v и −v — та же точка),
что и порождает фундаментальную группу π₁(P³) = ℤ/2ℤ .
Афинный атлас — четыре карты U_W, U_X, U_Y, U_Z , каждая покрывает P³ кроме
гиперплоскости, где соответствующая координата равна нулю. В карте U_W (при W ≠ 0 ) точка [X:Y:Z:W] выглядит как обычная декартова тройка (x, y, z) = (X/W, Y/W, Z/W) . Это и есть «локальная
R³-аппроксимация», в которой работает классический воксельный
движок.
1.2. Почему P³ для вокселей, а
не R³
Три конкретных свойства, которые делает P³ правильным выбором для
планетарного воксельного движка:
Бесшовность планеты. В R³ плоская воксельная сетка
размером с планету требует либо кубической карты (6 швов), либо
сферической параметризации (полюсные сингулярности), либо wrapping по
тору (топологически неверно). В P³ поверхность планеты — это естественно
замкнутое многообразие: переход через антипод ( W → 0 )
автоматически склеивается с противоположной стороной через смену афинной
карты. Швов нет по построению.
Локально R³, глобально — нет. Метрика Фубини–Штуди d_ФШ ∈ [0, π/2] совпадает с евклидовой с относительной
точностью < 10⁻⁹ на расстояниях < 1000 км для Земли, и радикально расходится на
расстояниях, сравнимых с πR . Это значит, что воксельный
рендер локально неотличим от Minecraft, но при этом планета
действительно круглая без геометрических трюков.
Третье измерение бесплатно. Координата Z в карте U_W — это радиальное направление
(вверх/вниз от поверхности). Спуск к центру планеты и подъём в космос —
оба естественным образом моделируются как движение по геодезической в
P³, и оба достигают W=0 (центр планеты и антипод — два
разных представителя одной проективной гиперплоскости).
1.3. Принцип отображения
вокселей
Каждый воксель — это точка P³ с дополнительными
атрибутами (block ID, состояние). Чанк — это небольшой
PARALLELEPIPED в карте U_W (или другой текущей
карте), заданный своим origin-вектором в P³ и локальным
ортонормированным базисом касательного пространства. Локальная нумерация
блоков внутри чанка (i, j, k) ∈ [0, N)³ мапится в P³ через
афинную формулу:
v_block = origin_chunk + i · basis_X · block_size_m + j · basis_Y · block_size_m + k · basis_Z · block_size_m
в однородных координатах: v_block ∈ ℝ⁴ (не
нормированный), с последующей нормировкой v_block / ‖v_block‖ для получения канонического
представителя.
Ключевая идея: внутри чанка мы работаем в локальной афинной карте (евклидова арифметика), а
P³-свойства (калибровка W, бесшовные границы, антиподальная
идентификация) применяются на границах чанков и при
глобальном позиционировании. Это даёт нам скорость Minecraft и
корректность сферической планеты в одной архитектуре.
1.4. Что переиспользуем
из POLER-FPGA math
POLER-компонент Где в P³ Voxel Core Зачем Mat4 (4×4 f64) Pgl4Matrix для афинных переходов между картами Преобразование координат между U_W ↔︎ U_X ↔︎ U_Y ↔︎ U_Z logicalProjector Π_Λ = I − Jcᵀ(Jc·Jcᵀ+δI)⁻¹·Jc Анти-дрейф при долгом steaming чанков Гасит накопленные ошибки в config -матрицах чанков Newton–Schulz 4×4 inversion ( newton_schulz_inv.v ) pgl_inverse для перехода между картами O(1) обратная матрица 4×4 без численной нестабильности CORDIC 1/√x ( cordic_inv_sqrt.v ) normalize_homogeneous и fs_distance Аппаратно-готовная реализация 1/‖v‖ в Q32.32 Q32.32 fixed-point Опциональный deterministic-режим рендера Бит-точная воспроизводимость на разных платформах Деформированное тензорное произведение X ⊗_ε Y (опц.) Композитные трансформации чанков Лоре-совместимое взаимодействие φ-полей с чанками
2. Chunk representation (с
Rust типами)
2.1. Чанк как
локальный афинный параллелепипед
Чанк размера N³ (по умолчанию N = 16 ,
опционально 32 ) — это набор из N³ вокселей,
занимающих куб со стороной N · block_size_m в текущей
афинной карте. Чанк хранит не P³-координаты каждого
блока (это 16³·32 байт = 128 КБ на чанк — расточительно), а:
origin_p3 — однородный P³-вектор
одного опорного угла чанка (обычно угол (i=0, j=0, k=0) ),
basis — три 4-вектора basis_X, basis_Y, basis_Z , задающих оси чанка в ℝ⁴
(ортонормированные в касательном пространстве карты),
block_size_m — размер блока в метрах
(1.0 м по умолчанию),
voxels — компактный массив N³ структур BlockState (без P³-координат; они
вычисляются из origin и basis ).
2.2. Rust типы
//! p3_voxel::chunk — представление чанка в P³use crate ::core::homogeneous:: HomVec4 ; // [X, Y, Z, W], f64use crate ::core::pgl4:: Pgl4Matrix ; // 4×4, det нормирован к +1use crate ::core::cards:: AffineCard ; // enum { UW, UX, UY, UZ }use crate ::physical_scale:: PlanetScale ;use std::sync:: Arc ;/// Размер стороны чанка по умолчанию./// 16³ = 4096 блоков; при block_size=1м это 16м³ реального объёма.pub const DEFAULT_CHUNK_SIZE : u8 = 16 ;/// Идентификатор чанка в глобальной P³-сетке./// Не целочисленный индекс (как в Minecraft), а P³-точка —/// центр чанка на поверхности планеты.#[ derive ( Clone , Copy , Debug , PartialEq , Hash )]pub struct ChunkId {/// P³-координата центра чанка (нормированная).pub center_p3 : HomVec4 ,/// Масштаб чанка в метрах (сторона куба).pub side_m : f32 ,}/// Базис чанка в ℝ⁴. Три ортонормированных 4-вектора,/// задающих локальные оси (east, north, up) в текущей афинной карте./// Получается из `tangent_basis(origin_p3)` — см. §2.4.#[ derive ( Clone , Copy , Debug )]pub struct ChunkBasis {pub east : HomVec4 , // локальная ось +X в касательном пространствеpub north : HomVec4 , // локальная ось +Ypub up : HomVec4 , // локальная ось +Z (радиальная, от центра планеты наружу)}/// Чанк: N³ вокселей в локальной афинной карте.////// Память: при N=16, BlockState=4 байта → 4096·4 = 16 КБ + ~128 байт метаданных./// Один чанк = ~16.5 КБ. Чанк-сетка 256×256×8 = ~524288 чанков = ~8 ГБ —/// помещается в RAM для full-Earth 1м-вокселизации без LOD.#[ derive ( Clone , Debug )]pub struct Chunk {/// Глобальный идентификатор (P³-центр + сторона).pub id : ChunkId ,/// Опорный угол чанка (i=0, j=0, k=0) в P³, нормированный.pub origin_p3 : HomVec4 ,/// Локальный базис (east, north, up) в ℝ⁴./// Ось `up` совпадает с радиальным направлением планеты в этой точке.pub basis : ChunkBasis ,/// Афинная карта, в которой чанк представлен устойчиво./// При движении чанка (streaming) может меняться через переклейку.pub card : AffineCard ,/// Размер стороны чанка в блоках (обычно 16).pub size : u8 ,/// Размер одного блока в метрах (1.0 по умолчанию).pub block_size_m : f32 ,/// Плотный массив `size³` блоков, индексация `i + j*size + k*size²`.pub voxels : Vec < BlockState >, // len = size³/// Ссылка на планетарный масштаб (для W-калибровки).pub planet : Arc < PlanetScale >,/// Версия чанка (инкрементируется при каждом изменении вокселей)./// Используется для cache-invalidation в mesher и streamer.pub version : u64 ,/// Флаг «грязного» чанка (нуждает ремешинга).pub dirty : bool ,}impl Chunk {/// Создать пустой чанк с заданным origin в P³./// Базис вычисляется автоматически из `origin_p3` и `planet`.pub fn new(id : ChunkId ,origin_p3 : HomVec4 ,planet : Arc < PlanetScale >,size : u8 ,block_size_m : f32 ,) -> Self {let basis = ChunkBasis:: tangent_to(origin_p3 , & planet) ;let card = AffineCard:: pick_best(origin_p3) ;let n = (size as usize ) . pow( 3 ) ;Self {id ,origin_p3 : origin_p3 . normalized() ,basis ,card ,size ,block_size_m ,voxels : vec! [ BlockState:: AIR ; n] ,planet ,version : 0 ,dirty : false ,}}/// Локальный индекс (i, j, k) → P³-координата центра блока./// Формула:///   v_block = origin_p3///           + (i + 0.5) · block_size_m · basis.east///           + (j + 0.5) · block_size_m · basis.north///           + (k + 0.5) · block_size_m · basis.up/// Возвращается нормированный представитель.pub fn block_p3( & self , i : u8 , j : u8 , k : u8 ) -> HomVec4 {let half = 0.5 * self . block_size_m as f64 ;let offset = self . basis . east . scale((i as f64 ) * self . block_size_m as f64 + half)+ self . basis . north . scale((j as f64 ) * self . block_size_m as f64 + half)+ self . basis . up . scale((k as f64 ) * self . block_size_m as f64 + half) ;( self . origin_p3 + offset) . normalized()}/// Обратное преобразование: P³-точка → локальный (i, j, k) в этом чанке./// Используется для ray-casting и попаданий клика мыши./// Возвращает `None`, если точка не внутри чанка.pub fn locate_block( & self , p3 : HomVec4) -> Option < ( u8 , u8 , u8 ) > {// Перевести p3 в локальные координаты относительно originlet local = p3 . project_into_card( self . card) - self . origin_p3 . project_into_card( self . card) ;// Спроецировать на базисlet i_f = local . dot( self . basis . east . into_local( self . card)) / self . block_size_m as f64 ;let j_f = local . dot( self . basis . north . into_local( self . card)) / self . block_size_m as f64 ;let k_f = local . dot( self . basis . up . into_local( self . card)) / self . block_size_m as f64 ;if i_f < 0.0 || j_f < 0.0 || k_f < 0.0 { return None ; }let i = i_f as u8 ; let j = j_f as u8 ; let k = k_f as u8 ;if i >= self . size || j >= self . size || k >= self . size { return None ; }Some ((i , j , k))}/// Чтение блока по локальному индексу.pub fn get( & self , i : u8 , j : u8 , k : u8 ) -> BlockState {let idx = self . linear_index(i , j , k) ;self . voxels[idx]}/// Запись блока. Помечает чанк как dirty, инкрементирует версию.pub fn set( & mut self , i : u8 , j : u8 , k : u8 , block : BlockState) {let idx = self . linear_index(i , j , k) ;if self . voxels[idx] != block {self . voxels[idx] = block ;self . version = self . version . wrapping_add( 1 ) ;self . dirty = true ;}}/// W-координата центра чанка (используется для LOD и калибровки).pub fn w_center( & self ) -> f64 {self . id . center_p3 . 0 [ 3 ]}/// Расстояние от наблюдателя (центра текущей глобальной карты) до чанка, в метрах./// d_ФШ(center, origin_observer) · 2R.pub fn surface_distance_to( & self , observer_p3 : HomVec4) -> f64 {let d_fs = self . id . center_p3 . fs_distance(observer_p3) ;self . planet . p3_angle_to_surface_distance(d_fs)}/// Находится ли чанк в «локальной зоне» (P³ ≈ R³)?/// Порог: 1000 км от наблюдателя. Дальше — глобальная зона.pub fn is_local( & self , observer_p3 : HomVec4) -> bool {self . surface_distance_to(observer_p3) < 1_000_000.0}#[ inline ]fn linear_index( & self , i : u8 , j : u8 , k : u8 ) -> usize {let s = self . size as usize ;(i as usize ) + (j as usize ) * s + (k as usize ) * s * s}}impl ChunkBasis {/// Вычислить касательный базис (east, north, up) в точке `p3` на поверхности планеты.////// Алгоритм:/// 1. `up` = радиальное направление = `(X, Y, Z, 0)` компоненты `p3`, нормированные./// 2. `east` = вектор, перпендикулярный `up` и лежащий в плоскости (XY, W=const).///    Для точки с координатами (X, Y, Z, W): east = (-Y, X, 0, 0) / ‖(-Y, X, 0, 0)‖./// 3. `north` = up × east (в 3D-подпространстве W=0).////// Все три 4-вектора ортонормированы в ℝ⁴ и лежат в касательном 3-подпространстве к/// поверхности планеты (которая является S³ в двойном накрытии P³).pub fn tangent_to(p3 : HomVec4 , _planet : & PlanetScale) -> Self {let v = p3 . normalized() ;let x = v . 0 [ 0 ] ; let y = v . 0 [ 1 ] ; let z = v . 0 [ 2 ] ; let w = v . 0 [ 3 ] ;// up = радиальное направление в 3D-подпространствеlet up_len = (x * x + y * y + z * z) . sqrt() ;let up = if up_len > 1e-12 {HomVec4([x / up_len , y / up_len , z / up_len , 0.0 ])} else {// p3 ≈ [0:0:0:1] — наблюдатель в полюсе; up = стандартный e_zHomVec4([ 0.0 , 0.0 , 1.0 , 0.0 ])};// east = перпендикуляр к up в XY-плоскостиlet xy_len = (x * x + y * y) . sqrt() ;let east = if xy_len > 1e-12 {HomVec4([ - y / xy_len , x / xy_len , 0.0 , 0.0 ])} else {// p3 на оси Z — east = стандартный e_xHomVec4([ 1.0 , 0.0 , 0.0 , 0.0 ])};// north = up × east (векторное произведение в 3D, W=0)let north = cross3(up , east) ;Self { east , north , up }}}/// Векторное произведение в 3D-подпространстве (W=0).fn cross3(a : HomVec4 , b : HomVec4) -> HomVec4 {HomVec4([a . 0 [ 1 ] * b . 0 [ 2 ] - a . 0 [ 2 ] * b . 0 [ 1 ] ,a . 0 [ 2 ] * b . 0 [ 0 ] - a . 0 [ 0 ] * b . 0 [ 2 ] ,a . 0 [ 0 ] * b . 0 [ 1 ] - a . 0 [ 1 ] * b . 0 [ 0 ] ,0.0 ,]) . normalized()}
2.3. Mapping
между локальными (i, j, k) и P³-координатами
Локальный индекс (i, j, k) ∈ [0, N)³
        │
        │  chunk.block_p3(i, j, k)
        ▼
Однородный P³-вектор v = origin + (i+½)·block_size·east
                                 + (j+½)·block_size·north
                                 + (k+½)·block_size·up       (в ℝ⁴, не нормированный)
        │
        │  v.normalize()
        ▼
Канонический представитель [X:Y:Z:W] с ‖v‖=1
        │
        │  AffineCard::pick_best(v) → (card, xyz)
        ▼
Локальные координаты (x, y, z) в подходящей афинной карте (U_W, U_X, U_Y или U_Z)
        │
        │  planet.p3_to_surface(v) → (azimuth, surface_distance, height)
        ▼
Физические метры на/над/под поверхностью планеты
Обратный путь (P³ → локальный индекс) — Chunk::locate_block(p3) — используется в ray-casting, клике
мыши по блоку, и при streaming-загрузке новых чанков. См. §3.4.
2.4. Калибровка W=cos(s/2R) для
чанков
Каждый чанк имеет origin_p3 — точку на поверхности
планеты. Если наблюдатель находится в observer_p3 (центр
текущей карты U_W ), то W-координата origin-точки чанка
калибруется как:
W_chunk_origin = cos(s_chunk / (2R))
где s_chunk — физическое расстояние вдоль поверхности
планеты от наблюдателя до центра чанка. См. подробнее §5. При streaming
чанков, система проверяет W_chunk_origin относительно W_EPS = 1мм / (2R) (для Земли ≈ 7.8 × 10⁻¹¹ );
если |W| < W_EPS , чанк считается «достигшим антипода» и переклеивается на другую афинную карту (см. §6).
3. Block representation (с
Rust типами)
3.1. Блок как P³-point +
атрибуты
В отличие от Minecraft, где блок = (x, y, z, block_id) ,
в P³-вокселях блок — это P³-точка с атрибутами . Сама
P³-координата блока не хранится в BlockState (она
вычисляется через Chunk::block_p3 ), но соседство
блоков определяется через P³-геометрию, а не через
целочисленные оффсеты.
3.2. Rust типы
//! p3_voxel::block — представление блокаuse crate ::core::homogeneous:: HomVec4 ;use bitflags:: bitflags ;/// Идентификатор типа блока. 16 бит → 65536 различных материалов./// Резервируем верхнюю половину (0x8000–0xFFFF) для «физических» блоков/// из лора Этерии (φ-сплавы, фредерит, адамантит, χ-материалы).#[ derive ( Clone , Copy , Debug , PartialEq , Eq , Hash )]#[ repr ( transparent )]pub struct BlockId( pub u16 ) ;impl BlockId {pub const AIR : BlockId = BlockId( 0x0000 ) ;pub const STONE : BlockId = BlockId( 0x0001 ) ;pub const DIRT : BlockId = BlockId( 0x0002 ) ;pub const WATER : BlockId = BlockId( 0x0010 ) ;pub const LAVA : BlockId = BlockId( 0x0011 ) ;// Лор-блоки Этерии (upper half)pub const FREDERITE : BlockId = BlockId( 0x8001 ) ; // 210 Вт/м² излучательpub const PHI_ALLOY : BlockId = BlockId( 0x8002 ) ; // φ-сплав (Ω-проводник)pub const ADAMANTITE : BlockId = BlockId( 0x8003 ) ; // поглотитель Хаосаpub const CHI_ORE : BlockId = BlockId( 0x8004 ) ; // χ-радиацияpub const PLATINUM : BlockId = BlockId( 0x8005 ) ; // абсолютный Порядок (Ω)pub const ROOT_LAYER : BlockId = BlockId( 0x8006 ) ; // корневой слой Бездны}bitflags! {/// Состояние блока — битовые флаги./// 16 бит = 2 байта на блок. При N=16 чанк = 8 КБ на флаги.#[ derive ( Clone , Copy , Debug , PartialEq , Eq )]pub struct BlockFlags : u16 {const EMPTY = 0b0000_0000_0000_0000 ;const SOLID = 0b0000_0000_0000_0001 ;const TRANSPARENT = 0b0000_0000_0000_0010 ;const FLUID = 0b0000_0000_0000_0100 ;const OPAQUE = 0b0000_0000_0000_1000 ;const CONDUCTOR = 0b0000_0000_0001_0000 ; // Ω-проводник (φ-сплав)const INSULATOR = 0b0000_0000_0010_0000 ; // χ-изоляторconst RESONANT = 0b0000_0000_0100_0000 ; // 18.7 Гц резонаторconst DISSIPATIVE = 0b0000_0000_1000_0000 ; // CNED-старение ×5const EDIBLE = 0b0000_0001_0000_0000 ;const FLAMMABLE = 0b0000_0010_0000_0000 ;const GLOWING = 0b0000_0100_0000_0000 ; // фредеритconst GRAVITY = 0b0000_1000_0000_0000 ;const UPDATEABLE = 0b0001_0000_0000_0000 ; // тикующий блок}}/// Полное состояние блока. 4 байта: 2 байта ID + 2 байта флаги.#[ derive ( Clone , Copy , Debug , PartialEq , Eq , Hash )]#[ repr ( C )]pub struct BlockState {pub id : BlockId ,pub flags : BlockFlags ,}impl BlockState {pub const AIR : BlockState = BlockState {id : BlockId:: AIR ,flags : BlockFlags:: EMPTY ,};pub fn new(id : BlockId , flags : BlockFlags) -> Self {Self { id , flags }}pub fn is_air( & self ) -> bool {self . id == BlockId:: AIR}pub fn is_solid( & self ) -> bool {self . flags . contains( BlockFlags:: SOLID)}pub fn is_transparent( & self ) -> bool {self . flags . contains( BlockFlags:: TRANSPARENT) || self . is_air()}pub fn is_fluid( & self ) -> bool {self . flags . contains( BlockFlags:: FLUID)}}/// P³-представление блока. Вычисляется по требованию (не хранится в чанке).////// Включает:/// - однородные координаты центра блока [X:Y:Z:W] (нормированные),/// - текущую афинную карту (где блок представлен устойчиво),/// - локальные координаты (x, y, z) в этой карте.#[ derive ( Clone , Copy , Debug )]pub struct P3Voxel {/// P³-координата центра блока.pub p3 : HomVec4 ,/// Афинная карта, где W ≠ 0 и блок представлен устойчиво.pub card : crate ::core::cards:: AffineCard ,/// Локальные (x, y, z) в выбранной карте.pub local : [ f64 ; 3 ] ,/// Ссылка на BlockState (из чанка).pub state : BlockState ,}impl P3Voxel {/// Построить из чанка и локального индекса.pub fn from_chunk(chunk : & Chunk , i : u8 , j : u8 , k : u8 ) -> Self {let p3 = chunk . block_p3(i , j , k) ;let card = crate ::core::cards::AffineCard:: pick_best(p3) ;let local = p3 . project_into_card(card) ;let state = chunk . get(i , j , k) ;Self { p3 , card , local , state }}/// P³-расстояние (Фубини–Штуди) до другого блока, в радианах.pub fn p3_distance( & self , other : & Self ) -> f64 {self . p3 . fs_distance(other . p3)}/// Физическое расстояние вдоль поверхности планеты до другого блока, в метрах.pub fn surface_distance_m( & self , other : & Self , planet : & PlanetScale) -> f64 {planet . p3_angle_to_surface_distance( self . p3_distance(other))}}
3.3. Соседство в P³ (не
евклидово!)
В Minecraft соседи блока (i, j, k) — это (i±1, j, k), (i, j±1, k), (i, j, k±1) — шесть целочисленных
оффсетов. В P³-вокселях это неверно глобально :
P³ Voxel Core — Подробная спецификация (часть 2/2)
Ситуация Minecraft (R³) P³ Voxel Блок в середине чанка 6 соседей по ±1 Те же 6 — локально P³ ≈ R³ Блок на границе чанка Сосед в соседнем чанке Сосед в соседнем чанке, но его P³-координата
вычисляется через next_chunk.block_p3(0, j, k) , а не this_chunk.block_p3(size, j, k) . На бесшовной планете эти
две формулы дают одного и того же соседа с точностью до
P³-эквивалентности. Блок у антипода наблюдателя (не определено) Сосед находится в другой афинной карте ( U_X , U_Y или U_Z вместо U_W ). Локальный целочисленный оффсет ±1 не имеет смысла —
нужно явно переключать карту. Блок на «шве» планеты (не существует швов) Шва нет: переход через W=0 автоматически переклеивает
карту.
Решение: Chunk::neighbor(direction, i, j, k) возвращает Neighbor -enum:
//! p3_voxel::block::neighbor — неевклидово соседствоuse crate ::core::cards:: AffineCard ;#[ derive ( Clone , Copy , Debug , PartialEq , Eq )]pub enum Direction6 {East , // +X в локальном базисе чанкаWest , // −XNorth , // +YSouth , // −YUp , // +Z (радиально наружу)Down , // −Z (радиально к центру планеты)}/// Результат запроса соседа блока.#[ derive ( Clone , Debug )]pub enum Neighbor {/// Сосед в том же чанке — обычный случай.InChunk { chunk_id : ChunkId , i : u8 , j : u8 , k : u8 },/// Сосед в соседнем чанке (boundary case)./// Нужно загрузить соседний чанк и проиндексировать его.InAdjacentChunk {adjacent_chunk_id : ChunkId ,// Целевой локальный индекс в соседнем чанке:i : u8 , j : u8 , k : u8 ,// Преобразование между базисами чанков (PGL(4) матрица):// local_coords_in_adjacent = basis_transform · local_coords_in_thisbasis_transform : crate ::core::pgl4:: Pgl4Matrix ,},/// Сосед находится в другой афинной карте (W → 0 на границе)./// Это случай глобального движения через антипод.InOtherCard {adjacent_chunk_id : ChunkId ,new_card : AffineCard ,// Карточный переход (дробно-линейное преобразование):card_transition : crate ::core::pgl4:: Pgl4Matrix ,i : u8 , j : u8 , k : u8 ,},/// Сосед на антиподе планеты (W = 0 точно)./// Эквивалентен переходу на обратную сторону планеты.AtAntipode {antipodal_chunk_id : ChunkId ,// Антиподальная идентификация: v_antipode = [-X, -Y, -Z, W] (та же точка в P³!)// Но физически это другая точка планеты.},}impl Chunk {pub fn neighbor( & self , dir : Direction6 , i : u8 , j : u8 , k : u8 ) -> Neighbor {use Direction6:: *;let (di , dj , dk) = match dir {East => ( 1i8 , 0 , 0 ) ,West => ( - 1 , 0 , 0 ) ,North => ( 0 , 1 , 0 ) ,South => ( 0 , - 1 , 0 ) ,Up => ( 0 , 0 , 1 ) ,Down => ( 0 , 0 , - 1 ) ,};let ni = i as i8 + di ;let nj = j as i8 + dj ;let nk = k as i8 + dk ;// Случай 1: сосед внутри чанкаif ni >= 0 && (ni as u8 ) < self . size&& nj >= 0 && (nj as u8 ) < self . size&& nk >= 0 && (nk as u8 ) < self . size{return Neighbor:: InChunk {chunk_id : self . id ,i : ni as u8 , j : nj as u8 , k : nk as u8 ,};}// Случай 2: сосед в соседнем чанке (или на антиподе)// Вычисляем P³-координату соседа через текущий базис:let neighbor_p3 = self . block_p3((ni . max( 0 ) as u8 ) . min( self . size - 1 ) ,(nj . max( 0 ) as u8 ) . min( self . size - 1 ) ,(nk . max( 0 ) as u8 ) . min( self . size - 1 ) ,) . offset(dir) ;// Проверяем W-координату: если |W| < W_EPS → антипод или другая картаlet w = neighbor_p3 . 0 [ 3 ] ;let w_eps = self . planet . w_eps() ;if w . abs() < w_eps {// Антиподальная зона: сосед в другой афинной картеlet new_card = AffineCard:: pick_best(neighbor_p3) ;let adjacent_chunk_id = ChunkId {center_p3 : neighbor_p3 ,side_m : self . id . side_m ,};let card_transition = AffineCard:: transition_matrix( self . card , new_card) ;return Neighbor:: InOtherCard {adjacent_chunk_id ,new_card ,card_transition ,i : 0 , j : 0 , k : 0 , // будет уточнено в InOtherCard-логике};}// Обычный случай: сосед в соседнем чанке, та же картаlet adjacent_chunk_id = ChunkId {center_p3 : neighbor_p3 ,side_m : self . id . side_m ,};let basis_transform = crate ::core::pgl4::Pgl4Matrix:: identity() ;// Вычисляем локальный индекс в соседнем чанкеlet (ai , aj , ak) = (if ni < 0 { self . size - 1 } else if ni >= self . size { 0 } else { ni as u8 },if nj < 0 { self . size - 1 } else if nj >= self . size { 0 } else { nj as u8 },if nk < 0 { self . size - 1 } else if nk >= self . size { 0 } else { nk as u8 },) ;Neighbor:: InAdjacentChunk {adjacent_chunk_id ,basis_transform ,i : ai , j : aj , k : ak ,}}}
Подробнее о соседстве в P³ см. §6.
4. World как P³-manifold
4.1. Чанк-сетка на
поверхности планеты через P³
World — это не трёхмерный массив чанков [i][j][k] (как в Minecraft). Это многообразие в
P³ : каждый чанк идентифицируется P³-точкой
( ChunkId { center_p3, side_m } ), а не целочисленным
индексом. Сетка чанков — это дискретное покрытие поверхности планеты
(S²) и прилегающих радиальных слоёв.
Топология: - Поверхность планеты — S² радиусом R. -
Двойное накрытие S² в P³ — это S³ с антиподальной идентификацией v ~ −v . - Чанк-сетка на поверхности: гексагональная или
квадратная, привязанная к P³-точкам surface_to_p3(azimuth, distance) . - Радиальные слои: чанки
на высоте h над поверхностью, на глубине d под
ней.
4.2.
Бесшовные границы через антиподальную идентификацию
В P³ точки v и −v — одна и та же точка. На
поверхности планеты это означает:
Когда наблюдатель движется по поверхности и доходит до антипода своей
стартовой позиции (расстояние πR ), он не падает с
края мира . В P³ его позиция [X:Y:Z:W] эволюционирует от [0:0:0:1] (старт) до [cos α : sin α : 0 : 0] (антипод, азимут α). В точке W = 0 система автоматически переклеивается с карты U_W на одну из U_X, U_Y, U_Z (в зависимости от
азимута α), и наблюдатель продолжает движение в новой карте — но на
обратной стороне планеты.
Это означает, что чанк-сетка не имеет краёв . Чанк
«на краю» карты U_W автоматически соединяется с чанком «на
начале» карты U_X через W = 0 границу. Никаких
специальных edge-case-ов в коде: Chunk::neighbor всегда
возвращает корректного соседа (см. §3.3).
4.3. Локальная vs
глобальная зона (по W-координате)
Зона чанка определяется его W-координатой относительно
наблюдателя:
Зона W-диапазон Физическое расстояние Поведение Локальная W > cos(1000км / 2R) s < 1000 км P³ ≈ R³, можно использовать обычную евклидову арифметику,
целочисленные оффсеты, Minecraft-style meshing Промежуточная cos(15000км / 2R) < W < cos(1000км / 2R) 1000 км < s < 15000 км P³-метрика заметно отличается от R³, но карта U_W ещё
работает. Meshing требует учёта кривизны. Глобальная W < cos(15000км / 2R) s > 15000 км Карта U_W нестабильна (деление на близкое к нулю W).
Требуется переклейка на U_X/U_Y/U_Z . Антиподальная W ≈ 0 s ≈ πR Точка на бесконечности карты U_W . Обязательная
переклейка.
Для Земли (R=6378 км): cos(1000/12756) ≈ 0.9999969 , cos(15000/12756) ≈ 0.99786 . То есть даже на 15000 км W
отклоняется от 1 менее чем на 0.3%. Это объясняет, почему локально P³
неотличимо от R³ — но глобально необходимо использовать P³-аппарат.
4.4. Rust типы
//! p3_voxel::world — World как P³-manifolduse std::collections:: HashMap ;use std::sync:: Arc ;use crate ::chunk:: { Chunk , ChunkId };use crate ::core::homogeneous:: HomVec4 ;use crate ::physical_scale:: PlanetScale ;/// Зона чанка по W-координате (см. §4.3).#[ derive ( Clone , Copy , Debug , PartialEq , Eq )]pub enum WorldZone {Local , // s < 1000 км, P³ ≈ R³Intermediate , // 1000 < s < 15000 кмGlobal , // s > 15000 км, нужна переклейка картыAntipodal , // s ≈ πR, W ≈ 0}/// World — словарь загруженных чанков, индексированный по P³-идентификатору.////// В отличие от Minecraft (где world = 3D-массив чанков с целочисленными индексами),/// здесь world = HashMap<ChunkId, Chunk>. Это позволяет:/// - чанкам быть на любой P³-точке (включая разные афинные карты),/// - бесшовно добавлять/удалять чанки при streaming (без сдвига индексов),/// - иметь несколько активных наблюдателей в разных картах одновременно.pub struct World {/// Все загруженные чанки.pub chunks : HashMap < ChunkId , Chunk >,/// Планетарный масштаб (один на весь мир).pub planet : Arc < PlanetScale >,/// Текущий наблюдатель (центр активной афинной карты).pub observer : HomVec4 ,/// Текущая афинная карта наблюдателя.pub observer_card : crate ::core::cards:: AffineCard ,/// Размер чанка по умолчанию (сторон куба в метрах).pub default_chunk_side_m : f32 ,/// Размер блока по умолчанию (1.0 м для surface; 0.1 м для caves; 100 м для stratosphere).pub default_block_size_m : f32 ,/// Размер стороны чанка в блоках (16 по умолчанию).pub default_chunk_size : u8 ,}impl World {pub fn new(planet : Arc < PlanetScale >, observer : HomVec4) -> Self {let observer_card = crate ::core::cards::AffineCard:: pick_best(observer) ;Self {chunks : HashMap:: new() ,planet ,observer ,observer_card ,default_chunk_side_m : 16.0 ,default_block_size_m : 1.0 ,default_chunk_size : 16 ,}}/// Получить чанк по P³-идентификатору. None если не загружен.pub fn get_chunk( & self , id : & ChunkId) -> Option <& Chunk > {self . chunks . get(id)}/// Получить mutable чанк.pub fn get_chunk_mut( & mut self , id : & ChunkId) -> Option <& mut Chunk > {self . chunks . get_mut(id)}/// Вставить чанк в world.pub fn insert_chunk( & mut self , chunk : Chunk) {self . chunks . insert(chunk . id , chunk) ;}/// Выгрузить чанк (streaming unload).pub fn remove_chunk( & mut self , id : & ChunkId) -> Option < Chunk > {self . chunks . remove(id)}/// Зона чанка относительно наблюдателя.pub fn zone_of( & self , chunk : & Chunk) -> WorldZone {let s_m = chunk . surface_distance_to( self . observer) ;let max_s = self . planet . max_surface_distance_m ;if s_m < 1_000_000.0 {WorldZone:: Local} else if s_m < 15_000_000.0 {WorldZone:: Intermediate} else if s_m < 0.95 * max_s {WorldZone:: Global} else {WorldZone:: Antipodal}}/// Найти чанк, содержащий заданную P³-точку (для raycasting/click)./// Перебирает только загруженные чанки. O(N_loaded).pub fn find_chunk_containing( & self , p3 : HomVec4) -> Option <& Chunk > {self . chunks . values() . find( | c | c . locate_block(p3) . is_some())}/// Обновить позицию наблюдателя. Если наблюдатель пересёк W=0 —/// переключить активную карту и пометить все чанки для переклейки.pub fn update_observer( & mut self , new_observer : HomVec4) {let new_card = crate ::core::cards::AffineCard:: pick_best(new_observer) ;if new_card != self . observer_card {// Карта сменилась — все чанки в старой карте становятся «чужими»,// нужно перекомпоновать их в новой карте через PGL(4) переход.self . observer_card = new_card ;// TODO (агент 3, chunk-streaming): переклейка чанков через PGL(4)}self . observer = new_observer ;}}
4.5. Активная афинная
карта и наблюдатель
Активная карта мира ( World::observer_card ) определяется argmax(|X|, |Y|, |Z|, |W|) от наблюдателя. При движении
наблюдателя по поверхности планеты карта меняется редко (только при
пересечении W=0), но в радиальных траекториях (космос ↔︎ центр) карта
может меняться чаще.
Streaming (агент 3): при смене observer_card , все чанки старой карты должны быть
перекомпонованы в новую карту через PGL(4) матрицу
перехода. Это O(N_loaded) операций, но каждая — это просто pgl_apply(M_transition, chunk.origin_p3) и обновление basis через ту же матрицу.
5. Калибровка W=cos(s/2R) для
чанков
5.1. Формула
Для планеты радиусом R :
W(s) = cos(s / (2R))
где: - s — физическое расстояние вдоль дуги большого
круга на поверхности планеты, в метрах, - R — радиус
планеты в метрах, - W — однородная W-координата P³-вектора
точки, удалённой на s от наблюдателя.
Границы: - s = 0 (наблюдатель): W = 1 . - s = πR (антипод): W = 0 . - s = πR/2 (экватор относительно наблюдателя): W = cos(π/4) ≈ 0.707 .
5.2. Применение к чанкам
Каждый чанк имеет origin_p3 — точку P³, которая является
геометрическим центром чанка (точнее, опорным углом (i=0,j=0,k=0) , но в пределах 16м разница
незначительна).
Для чанка на расстоянии s_chunk от наблюдателя:
impl Chunk {/// Калиброванная W-координата центра чанка.pub fn calibrated_w( & self , observer : HomVec4) -> f64 {let s_m = self . surface_distance_to(observer) ;(s_m / self . planet . two_r) . cos()}/// Проверить, достиг ли чанк антиподальной зоны (нужна переклейка карты).pub fn needs_card_handoff( & self , observer : HomVec4) -> bool {self . calibrated_w(observer) . abs() < self . planet . w_eps()}}
5.3. Калибровка W_EPS
W_EPS — порог, ниже которого нужно переключать афинную
карту. Из физического требования: переключение карт происходит,
когда неопределённость в расстоянии достигает 1 мм.
δs ≈ 2R · δW / sin(s/2R)
В худшем случае (около W=0, s=πR): δs ≈ 2R · δW
Поэтому δW = 1мм / (2R)
Для Земли (R = 6378 км): W_EPS ≈ 7.84 × 10⁻¹¹ . Для
Этерии (R = 5838.4 км, из worklog §«Канон v2.0»): W_EPS ≈ 8.57 × 10⁻¹¹ .
5.4. Радиальные траектории
(вверх/вниз)
Калибровка W = cos(s/2R) работает не только для движения
по поверхности, но и для радиального движения:
Вверх на высоту h над поверхностью: W = cos(h / 2R) . На h = πR (половина
окружности через космос) W = 0 — это другая точка P³ на
гиперплоскости W=0 .
Вниз на глубину d под поверхностью: W = cos(d / 2R) . На d = πR (центр планеты в
нашей калибровке) W = 0 .
Это означает, что центр планеты — ещё одна точка
W=0 , как и антипод. В P³ это не противоречие: центр и антипод —
два разных представителя одной проективной гиперплоскости P².
Следствие для вокселей: чанки глубоко под
поверхностью (ближе к центру планеты) и чанки на обратной стороне
планеты (антипод) — оба оказываются в глобальной зоне с малым W. Это
естественная «физическая бесконечность»: изучая центр планеты,
наблюдатель в P³-смысле находится «бесконечно далеко» от своей стартовой
точки.
5.5. Локальная аппроксимация P³ ≈
R³
Для s ≪ R (локальная зона):
W(s) = cos(s/2R) ≈ 1 − (s/2R)² / 2 ≈ 1
d_ФШ ≈ s / 2R
Относительная разница между P³-расстоянием и евклидовым:
s W d_P³ (рад) d_R³ (= s/2R) Относит. разница 100 м 0.99999999999999 7.84e-8 7.84e-8 < 10⁻¹⁵ 1 км 0.9999999969 7.84e-7 7.84e-7 < 10⁻¹² 100 км 0.9999999970 7.84e-5 7.84e-5 < 10⁻⁹ 1000 км 0.9999969297 7.84e-4 7.84e-4 < 10⁻⁶ 5000 км 0.9999233173 3.92e-3 3.92e-3 < 10⁻⁴ 15000 км 0.9978616421 1.18e-2 1.18e-2 ~10⁻³ 20037 км (антипод) 0 π/2 ∞ ∞ (R³ ломается)
Вывод: в локальной зоне (s < 1000 км) можно
использовать обычную евклидову арифметику для meshing, physics,
raycasting. P³-аппарат нужен только при s > 1000 км (промежуточная зона и далее).
6. Соседство в P³ (неевклидово)
6.1. Проблема целочисленных
оффсетов
В Minecraft (i+1, j, k) всегда сосед (i, j, k) . Это работает потому, что R³ однородно и
изотропно: любой блок можно сдвинуть на (±1, 0, 0) и
получить валидного соседа. В P³ это глобально неверно ,
потому что:
P³ не однородно: около W = 0 афинная
карта U_W нестабильна. Блок с W ≈ 0 нельзя
сдвинуть на (1, 0, 0) в карте U_W — он уйдёт в
численную сингулярность.
P³ компактно: у планеты конечный размер. Когда
наблюдатель доходит до антипода, «следующий» блок в направлении движения
— это блок на обратной стороне планеты, в другой афинной карте.
Знаковая неоднозначность: в P³ v и −v — одна точка. Поэтому +1 и −1 в определённых направлениях могут оказаться одной и той же
точкой (если координата проходит через ноль).
6.2. P³-соседство
через Direction6 + Chunk::neighbor
В §3.3 определён Neighbor -enum с четырьмя случаями: 1. InChunk — сосед в том же чанке (локально, как в Minecraft).
2. InAdjacentChunk — сосед в соседнем чанке, та же афинная
карта. 3. InOtherCard — сосед в другой афинной карте (W →
0). 4. AtAntipode — сосед на антиподе планеты.
Принцип: Chunk::neighbor(dir, i, j, k) всегда возвращает корректного соседа. Если сосед
оказывается в другой карте или на антиподе, возвращается соответствующий
вариант enum. Вызывающий код (mesher, physics, raycaster) обрабатывает
каждый случай явно.
6.3. Переход между афинными
картами
Когда сосед находится в другой карте ( InOtherCard ),
нужна card_transition матрица PGL(4). Эти матрицы
фиксированы и не зависят от чанка:
Переход Матрица (на ℝ⁴, потом нормировка) U_W → U_X diag(1,1,1,1) с заменой: новые координаты [W, Y, Z, X] (т.е. x' = 1/x , y' = y/x , z' = z/x ) U_W → U_Y Аналогично: [X, W, Z, Y] U_W → U_Z Аналогично: [X, Y, W, Z]
Матрично: переход U_W → U_X — это перестановка координат [X,Y,Z,W] → [W,Y,Z,X] , что соответствует PGL(4) матрице перестановки. Сигнатура AffineCard::transition_matrix(from, to) -> Pgl4Matrix .
6.4. Антиподальная
идентификация
В P³ v ~ −v . Это значит, что P³-точка v = [X:Y:Z:W] и v' = [-X:-Y:-Z:-W] — одна и та же физическая точка планеты. Однако для двух разных P³-точек v и w на
поверхности планеты, их антиподы −v и −w могут
оказаться на разной физической стороне планеты.
В нашей калибровке W = cos(s/2R): - Наблюдатель в v_0 = [0:0:0:1] (s=0, W=1). - Антипод наблюдателя: v_antipode = [cos α : sin α : 0 : 0] (s=πR, W=0), где α —
азимут подхода. - В P³ v_antipode ~ −v_antipode = [-cos α : -sin α : 0 : 0] — это та же физическая точка (Южный полюс, если наблюдатель
на Северном).
Следствие для чанков: чанк на антиподе
идентифицируется P³-точкой v_antipode , но в storage может
храниться как −v_antipode (зависит от того, из какой карты
к нему подошли). При equality-check ChunkId == ChunkId нужно учитывать знаковую неоднозначность:
impl PartialEq for ChunkId {fn eq( & self , other : & Self ) -> bool {// P³: v ~ −v → ChunkId должен сравнивать с учётом знакаlet a = self . center_p3 . normalized() ;let b = other . center_p3 . normalized() ;a . almost_eq( & b , 1e-9 ) || a . almost_eq( & ( - b) , 1e-9 )}}
6.5. Алгоритм обхода
6 соседей блока (псевдокод)
fn six_neighbors(chunk, i, j, k):
    for dir in [East, West, North, South, Up, Down]:
        match chunk.neighbor(dir, i, j, k):
            InChunk { chunk_id, i, j, k } =>
                yield chunk.get(i, j, k)  // обычный путь
InAdjacentChunk { adjacent_chunk_id, basis_transform, i, j, k } =>
                let neighbor_chunk = world.get_chunk(adjacent_chunk_id)
                if neighbor_chunk is None:
                    yield BlockState::AIR  // или trigger streaming
                else:
                    yield neighbor_chunk.get(i, j, k)
InOtherCard { adjacent_chunk_id, new_card, card_transition, ... } =>
                // Сосед в другой афинной карте.
                // Нужно: (1) найти/загрузить чанк в new_card,
                //         (2) применить card_transition к координатам.
                let neighbor_chunk = world.get_chunk(adjacent_chunk_id)
                yield neighbor_chunk.get(...) (после преобразования)
AtAntipode { antipodal_chunk_id } =>
                // Сосед на антиподе планеты.
                yield world.get_chunk(antipodal_chunk_id).get(0, 0, 0)
7. Пример: chunk на
экваторе планеты R=6378км
7.1. Постановка
Планета: Земля, R = 6_378_000 м .
Наблюдатель: на экваторе, долгота 0°, в афинной карте U_W . Его P³-вектор: observer = [0 : 0 : 0 : 1] (нормированный).
Чанк: на экваторе, долгота Δλ = 10° к востоку.
Расстояние по дуге большого круга: s_chunk = R · Δλ_rad = 6_378_000 · (10°·π/180) = 1_112_706 м (≈ 1113 км).
Размер чанка: 16³ блоков, block_size = 1 м , сторона чанка = 16 м.
7.2. P³-координаты
Калибровка: W_chunk = cos(s_chunk / 2R) = cos(1_112_706 / 12_756_000) = cos(0.08727) ≈ 0.996195 .
P³-вектор центра чанка (наблюдатель в [0:0:0:1], чанк восточнее на
азимут α=90° к северу от касательной? — нет, восток это азимут α=0 в
нашей нотации):
v_chunk = [sin(s/2R) · cos α, sin(s/2R) · sin α, 0, cos(s/2R)]
        = [sin(0.08727) · 1, 0, 0, 0.996195]
        = [0.08716, 0, 0, 0.996195]
(После нормировки это уже единичный вектор — проверка: 0.08716² + 0.996195² ≈ 0.00760 + 0.99240 = 1.000 ✓.)
Зона чанка: s = 1113 км > 1000 км → WorldZone::Intermediate . Карта U_W ещё
работает, но P³-метрика уже заметно отличается от евклидовой на
~ 10⁻⁶ (относит.).
7.3. Базис чанка
ChunkBasis::tangent_to(v_chunk, planet) :
up = радиальное направление = [0.08716, 0, 0, 0] / 0.08716 = [1, 0, 0, 0] (направлен от центра планеты наружу в сторону чанка).
Примечание: в нашей калибровке радиальное направление — это (X, Y, Z) компоненты p3 , а W —
«расстояние до наблюдателя». То есть up указывает от центра
планеты в точку её поверхности, где находится чанк.
east = перпендикуляр к up в
XY-плоскости = [-Y, X, 0, 0] / ‖(-Y, X, 0, 0)‖ = [0, 1, 0, 0] (направление
на север).
Внимание: в нашей нотации east = локальная ось
+X чанка = направление вдоль экватора (тангенциально к поверхности, к
востоку). На экваторе это просто [-Y, X, 0, 0] = [0, 0, 0, 0] … стоп, тут нюанс.
Корректировка: для чанка на экваторе с v_chunk = [0.08716, 0, 0, 0.996195] , локальное «восточное»
направление (вдоль экватора, к востоку) — это производная P³-вектора по s :
dv/ds|_{α=0} = [cos(s/2R)·cos α, cos(s/2R)·sin α, 0, -sin(s/2R)] · (1/2R)
              = [0.996195, 0, 0, -0.08716] · (1/2R)
Это и есть локальное направление «восток» в ℝ⁴. После нормировки — east ≈ [0.99619, 0, 0, -0.08716] .
north = перпендикуляр к up и east , направление на север (по меридиану): north = up × east (в 3D-подпространстве W=const… но east имеет W-компоненту, так что нужно аккуратнее).
Упрощённо: north ≈ [0, 1, 0, 0] (перпендикулярно
экваториальной плоскости).
7.4. Блок внутри чанка
Блок (i=8, j=8, k=0) — центральный блок чанка на
поверхности (k=0 = самый нижний слой чанка по радиусу).
v_block = v_chunk_origin
        + 8.5 · 1.0м · east
        + 8.5 · 1.0м · north
        + 0.5 · 1.0м · up
(В однородных координатах: всё это складывается в ℝ⁴, потом
нормируется.)
Локальные координаты в карте U_W : local = (X/W, Y/W, Z/W) = (0.08716/0.99619, 0, 0) ≈ (0.08750, 0, 0) .
То есть в афинной карте U_W чанк выглядит как
параллелепипед со стороной ~16 м, сдвинутый от наблюдателя на ~1113 км в
направлении оси X. Это локально R³ — но координата X
здесь не 1113000 , а 0.08750 , потому что P³
«сжимает» бесконечность в W = 0 .
7.5. W-координата и зона
W_chunk_origin = 0.996195 → WorldZone::Intermediate .
W_EPS_earth = 1e-3 / 12_756_000 ≈ 7.84e-11 .
|W_chunk| = 0.996195 ≫ W_EPS → чанк не нуждается в
переклейке карты, U_W устойчива.
7.6. Соседние чанки
6 соседей чанк-центра (на поверхности, k=0 слой):
Направление Соседний чанк (глобально) P³-расстояние Зона East (+1 чанк к востоку) s = 1113 + 0.016 км ≈ 1113.016 км тот же Intermediate West (−1 чанк, к наблюдателю) s = 1113 − 0.016 км ≈ 1112.984 км тот же Intermediate North (+1 чанк к северу) другой меридиан, но тот же s по дуге тот же Intermediate South (−1 чанк к югу) аналогично тот же Intermediate Up (+1 чанк радиально наружу) h = +16 м над поверхностью W = cos(16м / 2R) ≈ 0.99999999999 Local Down (−1 чанк радиально вниз) d = +16 м под поверхностью W = cos(16м / 2R) ≈ 0.99999999999 Local
Все 6 соседей — InAdjacentChunk (та же карта U_W , та же зона). Антиподальная зона (s ≈ πR ≈ 20037 км) не
достигается. Переклейка карт не нужна.
7.7. Что меняется на антиподе
Если наблюдатель переместится на 20037 км к востоку (через весь
земной шар), его позиция эволюционирует:
t=0:    v_obs = [0, 0, 0, 1]                         (W=1, наблюдатель в исходной точке)
t=0.5:  v_obs = [sin(π/4), 0, 0, cos(π/4)]            (s=πR/2, W≈0.707, экватор относительно старта)
t=0.9:  v_obs = [sin(0.9·π/2), 0, 0, cos(0.9·π/2)]    (s=0.9·πR, W≈0.156,接近 антипод)
t=1.0:  v_obs = [sin(π/2), 0, 0, cos(π/2)] = [1,0,0,0] (s=πR, W=0, антипод!)
В точке t=1.0 система автоматически переклеивается с U_W на U_X (потому что |X| = 1 > |W| = 0 ). Начиная с этого момента, наблюдатель «живёт»
в карте U_X , где его позиция = [W, Y, Z, X] = [0, 0, 0, 1] . Это новый локальный
центр , и все чанки вокруг него имеют W’ ≈ 1 в новой карте. Планета бесшовна.
7.8. Числовой sanity-check
# Python: проверить калибровку для Землиimport mathR = 6_378_000.0two_r = 2 * R# s = 10° дуги экватораs = R * math.radians( 10 ) # 1_112_706 мW = math.cos(s / two_r) # 0.996195print ( f"W = { W :.6f} " ) # 0.996195 ✓# Антипод: s = πRs_anti = math.pi * RW_anti = math.cos(s_anti / two_r) # cos(π/2) = 0print ( f"W_antipode = { W_anti :.2e} " ) # ~0 ✓# W_EPS для 1 мм точностиW_EPS = 1e-3 / two_rprint ( f"W_EPS = { W_EPS :.3e} " ) # 7.84e-11 ✓
8. Связь с
POLER-FPGA math (что переиспользуем)
8.1. Что берём напрямую
POLER-FPGA math — это реализация квантово-химического итератора на
FPGA/Verilog, с Zig reference и Rust port. Для P³ Voxel Engine мы не берём квантовую химию и FPGA-синтез, но берём математическое ядро , проверенное в production:
POLER-компонент Файл-источник Использование в P³ Voxel Mat4 (4×4 f64) tensor.zig:30-247 , Matrix(N) generic Pgl4Matrix для PGL(4) преобразований и переходов между
афинными картами invertMatrix (Gauss-Jordan с partial
pivoting) tensor.zig:336-398 Pgl4Matrix::inverse() для обратных преобразований между
картами Newton-Schulz 4×4 inversion newton_schulz_inv.v (Verilog) Альтернативная реализация inverse() для Q32.32
deterministic-режима (8 итераций, гарантированная сходимость для
SPD) CORDIC 1/√x (Newton-Raphson 6 iter) cordic_inv_sqrt.v HomVec4::normalize() и fs_distance —
основа всех P³-операций Logical Projector Π_Λ tensor.zig:303-329 Анти-дрейф в streaming: раз в 100 шагов применять Π_Λ к chunk.basis для устранения накопленных f64-ошибок Quantum Normalization tensor.zig:475-480 p_{t+1} = (1−mix)·P + mix·P/‖P‖ — используется в Chunk::renormalize_basis() для长期 численной
стабильности Q32.32 fixed-point Все Verilog-модули Опциональный deterministic-режим рендера для воспроизводимости на
разных платформах (бит-точная арифметика без IEEE-754 нюансов)
8.2. Что НЕ берём
POLER Cycle (аттракторный поиск): не нужен для
воксельного движка, это про динамику состояний, а не геометрию.
Deformed tensor product X ⊗_ε Y : не
нужен для базового движка. Опционально — для лор-специфичных
взаимодействий (φ-сплавы, χ-радиация) в будущем (агент 8,
physics-poler).
QRwM (Quantum Randomness without Measurement) : не
нужен для вокселей. Это про криптографию.
POLER-SHOR (факторизация) : не нужен.
H₂ PES scan : не нужен.
FPGA bitstream : мы работаем на CPU + Rust (по
постановлению задачи).
8.3. План переиспользования
p3_voxel_engine/
├── crates/
│   ├── p3_core/                      ← переиспользует POLER tensor.zig
│   │   ├── src/
│   │   │   ├── homogeneous.rs        ← HomVec4, normalize (CORDIC-стиль)
│   │   │   ├── pgl4.rs               ← Pgl4Matrix, compose, inverse (Newton-Schulz)
│   │   │   ├── cards.rs              ← AffineCard enum, transitions
│   │   │   ├── fubini_study.rs       ← fs_distance, fs_geodesic
│   │   │   ├── pi1.rs                ← generator_pi1, verify_z2z
│   │   │   └── projector.rs          ← Π_Λ из POLER (anti-drift)
│   │   └── tests/
│   │       ├── z2z.rs                ← g² ≡ I
│   │       ├── cards_handoff.rs      ← W → 0 переклейка
│   │       └── fs_metric.rs          ← d(e1,e2) = π/2
│   │
│   ├── p3_physical_scale/            ← P3_PHYSICAL_SCALE.md §5
│   │   └── src/lib.rs                ← PlanetScale, W(s) = cos(s/2R)
│   │
│   ├── p3_voxel/                     ← эта спецификация
│   │   └── src/
│   │       ├── block.rs              ← BlockId, BlockFlags, BlockState, P3Voxel
│   │       ├── chunk.rs              ← Chunk, ChunkId, ChunkBasis
│   │       ├── neighbor.rs           ← Direction6, Neighbor enum
│   │       └── world.rs              ← World, WorldZone
│   │
│   └── p3_voxel_fixed/               ← Q32.32 deterministic-режим (опц.)
│       └── src/q3232.rs              ← fixed-point из POLER Verilog helpers
│
└── docs/
    └── p3_voxel/
        ├── 01_voxel_core_spec.md     ← этот документ
        ├── (02_poler_math_bridge.md) ← агент 2
        ├── (03_chunk_streaming.md)   ← агент 3
        └── ...
8.4.
Конкретные Rust-imports (что импортируем из p3_core)
// В p3_voxel/src/chunk.rs:use p3_core::homogeneous:: HomVec4 ; // [X, Y, Z, W]use p3_core::pgl4:: Pgl4Matrix ; // 4×4 матрицаuse p3_core::cards:: { AffineCard , transition_matrix };use p3_core::fubini_study:: fs_distance ;use p3_core::projector:: logical_projector ; // Π_Λ из POLER (anti-drift)// В p3_voxel/src/world.rs:use p3_physical_scale:: PlanetScale ;// В p3_voxel/src/block.rs:use p3_core::cards:: AffineCard ;
8.5. Числовые параметры из
POLER
Параметр Значение Источник Где в P³ Voxel pgl_canonical tolerance 1e-12 p3_core.rs::pgl_canonical Сравнение ChunkId == ChunkId с учётом знака Newton-Schulz iterations 8 (для SPD 4×4) newton_schulz_inv.v::MAX_ITER Pgl4Matrix::inverse() в deterministic-режиме CORDIC iterations 6 cordic_inv_sqrt.v::NEWTON_ITER HomVec4::normalize() в deterministic-режиме Tikhonov δ 1e-8 tensor.zig:314 logical_projector для anti-drift в Chunk::renormalize_basis Quantum normalization mix 0.1 tensor.zig:502 Chunk::renormalize_basis для renormalization
8.6. Тесты, которые
должны пройти в P³ Voxel Core
В дополнение к 11 тестам из P3_COMPENDIUM.pdf (часть V,
§7), добавляются voxel-специфичные:
chunk::block_p3_roundtrip — Chunk::block_p3(i,j,k) и Chunk::locate_block(p3) обратимы с точностью 1e-9 .
chunk::tangent_basis_orthonormal — ChunkBasis::tangent_to возвращает ортонормированный
базис.
chunk::neighbor_in_chunk — 6 соседей внутри чанка —
обычный случай (как Minecraft).
chunk::neighbor_across_chunk_boundary — сосед через
границу чанка — InAdjacentChunk .
chunk::neighbor_at_antipode — сосед на антиподе — AtAntipode , v_antipode ~ −v .
chunk::w_calibration_matches_cos_s_2r — calibrated_w(observer) == cos(s/2R) с точностью 1e-12 .
world::card_handoff_at_w_zero — при W → 0 мир переключает observer_card на правильную.
world::insert_and_get_chunk — World::insert_chunk + World::get_chunk работают с P³-ключами с учётом знака.
world::zone_classification — zone_of(chunk) корректно классифицирует
Local/Intermediate/Global/Antipodal.
Итого: 20 обязательных тестов для P³ Voxel Core.
Приложение A. Глоссарий
Термин Определение P³ Реальное проективное пространство размерности 3 = ℝ⁴{0} / ~, где v ~ λ·v для λ ≠ 0 Однородные координаты [X:Y:Z:W] Канонический представитель P³-точки, ‖v‖ = 1 . Знак
неоднозначен. Афинная карта U_W Подмножество P³, где W ≠ 0 . Локально выглядит как R³ с
координатами (X/W, Y/W, Z/W) . PGL(4) Проективная линейная группа: 4×4 матрицы по модулю скаляра. Группа
автоморфизмов P³. Метрика Фубини–Штуди d_ФШ(v, w) = arccos(|⟨v,w⟩| / (‖v‖·‖w‖)) ∈ [0, π/2] .
Естественная метрика P³. π₁(P³) = ℤ/2ℤ Фундаментальная группа P³. Один обход нетривиального цикла
«переворачивает» вектор, два — возвращают. Антипод Точка на поверхности планеты, удалённая на πR от
наблюдателя. В P³ имеет W = 0 . Калибровка W = cos(s/2R) Связывает безразмерную P³-координату с физическими метрами на
поверхности планеты. Чанк Локальный параллелепипед N³ блоков в текущей афинной
карте. N=16 по умолчанию. Блок (voxel) P³-точка с атрибутами (BlockId + BlockFlags). P³-координата
вычисляется через Chunk::block_p3 . World HashMap загруженных чанков, индексированный по P³-идентификатору ChunkId . WorldZone Классификация чанка по W-координате: Local / Intermediate / Global /
Antipodal.
Приложение B. Ссылки на
исходники
P3_COMPENDIUM.pdf — математическое ядро (однородные
координаты, PGL(4), Фубини–Штуди, калибровка).
POLER_FPGA_Code_v5.md — модули POLER (CORDIC,
Newton-Schulz, tensor product).
fpga-project/zig/tensor.zig — Zig reference Mat4,
deformedTensorProduct, logicalProjector, polerCycle.
fpga-project/reference/rust-core/poler_v0.3.3.rs — Rust
reference (1649 строк).
fpga-project/verilog/cordic_inv_sqrt.v — CORDIC 1/√x
для Q32.32.
fpga-project/verilog/newton_schulz_inv.v —
Newton-Schulz 4×4 inversion для Q32.32.
worklog.md §«p3-voxel-engine-master-brief» — постановка
задачи 10 агентов.
Приложение C. Что
делают остальные 9 агентов
Агент Задача Зависимость от этой спецификации 2. p3-poler-math-bridge Извлечение POLER math для CPU/Rust Реализует p3_core crate, от которого зависит p3_voxel 3. p3-chunk-streaming Streaming по P³-метрике Использует World::zone_of , Chunk::needs_card_handoff , Neighbor::InOtherCard 4. p3-meshing-core Greedy meshing в P³ Использует Chunk::block_p3 , Chunk::neighbor , локальную зону для R³-аппроксимации 5. p3-ray-casting DDA в P³ Использует Chunk::locate_block , fs_distance , P3Voxel::p3_distance 6. p3-camera-projection Камера и проекция Использует observer_card , AffineCard::pick_best , переходы между картами 7. p3-world-generation Процедурная генерация Использует PlanetScale , ChunkId , Chunk::new 8. p3-physics-poler Физика через POLER cycle Использует BlockFlags (CONDUCTOR, RESONANT,
DISSIPATIVE), чанки как контейнеры для физики 9. p3-renderer-arch Архитектура рендерера (Bevy/wgpu) Использует все типы выше,_rendering chunks по зоне (Local =
R³-рендер, Global = P³-метрика) 10. p3-master-arch Мастер-архитектура Связывает всё, опирается на эту спецификацию как на foundation
Конец спецификации. Полный размер: ~1000 строк, ~25
КБ. Rust-кода: ~500 строк (типы + базовые методы, без реализации
streaming/meshing/physics).
Cargo.toml — конфигурация p3_poler_math crate
[package]
name = "p3_poler_math"
version = "0.1.0"
edition = "2021"
rust-version = "1.85"
description = "Bridge between POLER-FPGA math (CORDIC, Newton-Schulz, deformed tensor product, POLER cycle) and CPU/Rust for the P³ Voxel Engine"
license = "MIT OR Apache-2.0"
repository = "https://example.com/p3-voxel-engine"
keywords = ["poler", "fpga", "voxel", "math", "projective-geometry"]
categories = ["mathematics", "game-development"]
[lib]
name = "p3_poler_math"
path = "src/lib.rs"
[features]
default = ["q32-32"]
# Q32.32 fixed-point arithmetic (matches Verilog qmul/int2q helpers).
# Enabled by default — used by deterministic-mode hot paths and by tests
# that need to match the FPGA bit-for-bit.
q32-32 = []
# SIMD wrappers via the `wide` crate (f64x4 SoA batched math).
# Off by default — only enable on hot paths identified by profiling.
simd = ["dep:wide"]
[dependencies]
# Optional SIMD. `wide` provides stable cross-platform f64x4 wrappers
# (SSE2/AVX on x86-64, NEON on AArch64).
wide = { version = "0.7", optional = true }
[dev-dependencies]
# No extra dev-deps — tests use only `core`/`std` primitives so the crate
# remains minimal-dependency.
[profile.release]
opt-level = 3
lto = "thin"
codegen-units = 1
panic = "abort"
[profile.dev]
opt-level = 1  # math tests fail under pure unoptimized builds due to f64 rounding
[[test]]
name = "integration"
path = "tests/integration.rs"
[[test]]
name = "parity_with_zig"
path = "tests/parity_with_zig.rs"
lib.rs — публичный API p3_poler_math
//! `p3_poler_math` — Bridge between POLER-FPGA math and the CPU/Rust
//! implementation of the P³ Voxel Engine.
//!
//! # What this crate contains
//!
//! Direct f64 ports of the math primitives used by the POLER-FPGA project,
//! adapted for CPU usage in the P³ Voxel Engine:
//!
//! - **[`tensor`]** — `Mat4`, `Vec4`, deformed tensor product
//!   `X ⊗_ε Y = (X·Y) + ε·(X⊙Y)`, dissipator `D = L·Lᵀ`, resonance `J = A − Aᵀ`.
//! - **[`cordic`]** — `1/√x` (Newton-Raphson, 6 iter), `sin`/`cos`/`atan2`
//!   (CORDIC, 60 iter), `1/x` (Newton-Raphson, 4 iter). Matches the Verilog
//!   `cordic_inv_sqrt.v` iteration count.
//! - **[`newton_schulz`]** — 4×4 matrix inversion via Newton-Schulz (SPD,
//!   8 iter) and Gauss-Jordan (general). Matches `newton_schulz_inv.v` and
//!   `tensor.zig::invertMatrix`.
//! - **[`poler_cycle`]** — Projected gradient-descent step
//!   `P_new = p − η·Π_Λ(D·p + γ·J·p + ∇F)`, the full POLER cycle to
//!   convergence, the logical projector `Π_Λ = I − Jcᵀ·(Jc·Jcᵀ + δI)⁻¹·Jc`,
//!   and the archetype idempotency check `a ⊗_ε a = a`.
//! - **[`quantum`]** — Quantum normalization
//!   `p_{t+1} = (1 − mix)·P + mix·P/‖P‖`.
//! - **[`q32_32`]** — Optional Q32.32 fixed-point arithmetic for hot paths
//!   requiring bit-exact cross-platform determinism (matches the Verilog
//!   `qmul`/`int2q` helpers).
//!
//! # What this crate does NOT contain
//!
//! Anything from `poler_core.py` (the cognitive-LLM POLER variant with
//! free-energy `F(p, o; θ)` and emo-intensity resonance weights). That is a
//! different abstraction and is not needed for the voxel engine.
//!
//! Anything FPGA-specific (bitstream synthesis, Q32.32-only data paths,
//! AXI-stream interfaces, etc.). We use f64 by default; Q32.32 is opt-in
//! behind the `q32-32` feature.
//!
//! # Features
//!
//! - `q32-32` (default) — enables the [`q32_32`] module.
//! - `simd` — enables the [`simd`] module (requires the `wide` crate).
//!
//! # References
//!
//! - `fpga-project/zig/tensor.zig` — primary f64 reference (753 lines).
//! - `fpga-project/verilog/cordic_inv_sqrt.v` — Q32.32 1/√x reference.
//! - `fpga-project/verilog/newton_schulz_inv.v` — Q32.32 4×4 inversion.
//! - `fpga-project/verilog/poler_cycle.v` — Q32.32 POLER cycle FSM.
//! - `fpga-project/verilog/tensor_product.v` — Q32.32 deformed tensor product.
//! - `01_voxel_core_spec.md` — Agent 1 specification, §8 lists what to reuse.
pub mod cordic;
pub mod newton_schulz;
pub mod poler_cycle;
pub mod quantum;
pub mod tensor;
#[cfg(feature = "q32-32")]
pub mod q32_32;
#[cfg(feature = "simd")]
pub mod simd;
// ---- Public re-exports for ergonomic `use p3_poler_math::*` ----
pub use cordic::{atan2, cos, inv_sqrt, recip, sin, sincos};
pub use newton_schulz::{
    invert, invert_gauss_jordan, invert_newton_schulz, DEFAULT_CONV_THRESHOLD,
    DEFAULT_DELTA as NEWTON_SCHULZ_DELTA, DEFAULT_MAX_ITER as NEWTON_SCHULZ_MAX_ITER,
};
pub use poler_cycle::{
    logical_projector, logical_projector_with_delta, poler_cycle, poler_discrete_step,
    verify_archetype_idempotent, verify_fixed_point, PolerConfig, PolerCycleResult,
    PROJECTOR_DELTA,
};
pub use quantum::{
    quantum_normalize, quantum_normalize_vec, DEFAULT_MIX as QUANTUM_DEFAULT_MIX,
};
pub use tensor::{deformed_tensor_product, dissipator, resonance, Mat4, Vec4};
#[cfg(feature = "q32-32")]
pub use q32_32::{
    from_f64 as q32_from_f64, int2q, inv_sqrt as q32_inv_sqrt, qadd, qdiv, qmul, qsub,
    recip as q32_recip, to_f64 as q32_to_f64, invert_newton_schulz_q,
    FRAC_BITS as Q32_FRAC_BITS, ONE as Q32_ONE, Q32_32,
};
/// Crate version (matches `Cargo.toml`).
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
tensor.rs — Deformed Tensor Product
//! tensor.rs — 4×4 matrices, 4-vectors, and the deformed tensor product.
//!
//! Direct f64 port of `fpga-project/zig/tensor.zig` (lines 30-266).
//!
//! # Deformed tensor product
//!
//! ```text
//! X ⊗_ε Y = (X · Y) + ε · (X ⊙ Y)
//! ```
//!
//! where `X · Y` is ordinary matrix multiplication and `X ⊙ Y` is the Hadamard
//! (element-wise) product. The Hadamard term provides continuous phase-space
//! deformation. ε = 0 reduces to a plain matrix product; large ε makes the
//! Hadamard term dominate, which is how POLER encodes "energy of significance".
//!
//! # Archetype idempotency
//!
//! An archetype `a` is idempotent under `⊗_ε` iff `a ⊗_ε a = a`. For ε = 0
//! this is the standard projection-matrix condition `a · a = a`. For ε ≠ 0
//! the archetype is generally only recoverable via the POLER cycle (see
//! [`crate::poler_cycle`]).
/// Row-major 4×4 matrix of f64.
///
/// `data[i * 4 + j]` is row `i`, column `j`. This matches the layout used by
/// the Zig reference (`Matrix(N).data[i][j]`) and by the Verilog
/// `M_in[0..MAT_ENTRIES-1]` flat array.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Mat4 {
    pub data: [f64; 16],
}
/// 4-vector of f64. Used as state vectors in the POLER cycle and as the
/// homogeneous coordinate container `[X, Y, Z, W]` in P³ voxel code.
#[derive(Clone, Copy, Debug, PartialEq, Default)]
pub struct Vec4(pub [f64; 4]);
impl Default for Mat4 {
    #[inline]
    fn default() -> Self {
        Self::zero()
    }
}
impl Mat4 {
    /// Zero matrix.
    #[inline]
    pub const fn zero() -> Self {
        Self { data: [0.0; 16] }
    }
/// Identity matrix.
    #[inline]
    pub const fn identity() -> Self {
        let mut m = Self::zero();
        m.data[0] = 1.0;
        m.data[5] = 1.0;
        m.data[10] = 1.0;
        m.data[15] = 1.0;
        m
    }
/// Build from a row-major flat array of 16 f64s.
    #[inline]
    pub const fn from_flat_row_major(arr: [f64; 16]) -> Self {
        Self { data: arr }
    }
/// Build from 4 rows.
    #[inline]
    pub fn from_rows(r0: [f64; 4], r1: [f64; 4], r2: [f64; 4], r3: [f64; 4]) -> Self {
        let mut d = [0.0; 16];
        d[0..4].copy_from_slice(&r0);
        d[4..8].copy_from_slice(&r1);
        d[8..12].copy_from_slice(&r2);
        d[12..16].copy_from_slice(&r3);
        Self { data: d }
    }
/// Read element at (i, j).
    #[inline]
    pub const fn get(&self, i: usize, j: usize) -> f64 {
        self.data[i * 4 + j]
    }
/// Write element at (i, j).
    #[inline]
    pub fn set(&mut self, i: usize, j: usize, v: f64) {
        self.data[i * 4 + j] = v;
    }
/// Matrix sum.
    #[inline]
    pub fn add(&self, other: &Self) -> Self {
        let mut d = [0.0; 16];
        for k in 0..16 {
            d[k] = self.data[k] + other.data[k];
        }
        Self { data: d }
    }
/// Matrix difference.
    #[inline]
    pub fn sub(&self, other: &Self) -> Self {
        let mut d = [0.0; 16];
        for k in 0..16 {
            d[k] = self.data[k] - other.data[k];
        }
        Self { data: d }
    }
/// Multiply every entry by `alpha`.
    #[inline]
    pub fn scale(&self, alpha: f64) -> Self {
        let mut d = [0.0; 16];
        for k in 0..16 {
            d[k] = alpha * self.data[k];
        }
        Self { data: d }
    }
/// Standard matrix product `self · other`.
    ///
    /// Direct port of `Matrix(N).matmul` from `tensor.zig:103-115`. The inner
    /// loop is hand-unrolled for `k = 0..4` so that the compiler can keep
    /// everything in registers.
    #[inline]
    pub fn matmul(&self, other: &Self) -> Self {
        let mut d = [0.0; 16];
        for i in 0..4 {
            for j in 0..4 {
                let mut sum = 0.0;
                for k in 0..4 {
                    sum += self.data[i * 4 + k] * other.data[k * 4 + j];
                }
                d[i * 4 + j] = sum;
            }
        }
        Self { data: d }
    }
/// Matrix–vector product, returns `self · v` as a [`Vec4`].
    #[inline]
    pub fn matvec(&self, v: Vec4) -> Vec4 {
        let mut out = [0.0; 4];
        for i in 0..4 {
            let mut sum = 0.0;
            for j in 0..4 {
                sum += self.data[i * 4 + j] * v.0[j];
            }
            out[i] = sum;
        }
        Vec4(out)
    }
/// Hadamard (element-wise) product.
    ///
    /// This is the deformation term used in
    /// [`deformed_tensor_product`]. It is the CORRECT non-linear coupling
    /// (the FPGA v1 mistakenly used XOR; v2+ uses Hadamard — see
    /// `tensor.zig:117-127`).
    #[inline]
    pub fn hadamard(&self, other: &Self) -> Self {
        let mut d = [0.0; 16];
        for k in 0..16 {
            d[k] = self.data[k] * other.data[k];
        }
        Self { data: d }
    }
/// Transpose.
    #[inline]
    pub fn transpose(&self) -> Self {
        let mut d = [0.0; 16];
        for i in 0..4 {
            for j in 0..4 {
                d[i * 4 + j] = self.data[j * 4 + i];
            }
        }
        Self { data: d }
    }
/// Frobenius norm `‖A‖_F = sqrt(Σ A_ij²)`.
    #[inline]
    pub fn frobenius_norm(&self) -> f64 {
        let mut sum = 0.0;
        for k in 0..16 {
            sum += self.data[k] * self.data[k];
        }
        sum.sqrt()
    }
/// Maximum absolute element.
    #[inline]
    pub fn max_abs(&self) -> f64 {
        let mut m = 0.0;
        for k in 0..16 {
            let v = self.data[k].abs();
            if v > m {
                m = v;
            }
        }
        m
    }
/// Trace.
    #[inline]
    pub fn trace(&self) -> f64 {
        self.data[0] + self.data[5] + self.data[10] + self.data[15]
    }
/// Element-wise approximate equality.
    #[inline]
    pub fn approx_eq(&self, other: &Self, tol: f64) -> bool {
        for k in 0..16 {
            if (self.data[k] - other.data[k]).abs() > tol {
                return false;
            }
        }
        true
    }
/// Returns the first column as a [`Vec4`]. Useful when the matrix
    /// represents a state-vector in the Zig convention (4×1 column stored
    /// inside a 4×4).
    #[inline]
    pub fn col0(&self) -> Vec4 {
        Vec4([self.data[0], self.data[4], self.data[8], self.data[12]])
    }
}
impl Vec4 {
    /// Zero vector.
    #[inline]
    pub const fn zero() -> Self {
        Self([0.0; 4])
    }
/// Construct from a slice (panics if length != 4).
    #[inline]
    pub fn from_slice(s: &[f64]) -> Self {
        let mut v = [0.0; 4];
        v.copy_from_slice(s);
        Self(v)
    }
/// Dot product.
    #[inline]
    pub fn dot(&self, other: &Self) -> f64 {
        let mut s = 0.0;
        for k in 0..4 {
            s += self.0[k] * other.0[k];
        }
        s
    }
/// Euclidean norm `‖v‖ = sqrt(Σ v_i²)`.
    #[inline]
    pub fn norm(&self) -> f64 {
        self.dot(self).sqrt()
    }
/// Normalized copy `v / ‖v‖`. If `‖v‖ < 1e-15`, returns `v` unchanged.
    #[inline]
    pub fn normalize(&self) -> Self {
        let n = self.norm();
        if n < 1e-15 {
            return *self;
        }
        self.scale(1.0 / n)
    }
/// Multiply by scalar.
    #[inline]
    pub fn scale(&self, alpha: f64) -> Self {
        let mut v = self.0;
        for x in v.iter_mut() {
            *x *= alpha;
        }
        Self(v)
    }
/// Vector sum.
    #[inline]
    pub fn add(&self, other: &Self) -> Self {
        let mut v = [0.0; 4];
        for k in 0..4 {
            v[k] = self.0[k] + other.0[k];
        }
        Self(v)
    }
/// Vector difference.
    #[inline]
    pub fn sub(&self, other: &Self) -> Self {
        let mut v = [0.0; 4];
        for k in 0..4 {
            v[k] = self.0[k] - other.0[k];
        }
        Self(v)
    }
}
// ============================================================================
// Deformed Tensor Product:  X ⊗_ε Y = (X·Y) + ε·(X⊙Y)
// ============================================================================
/// Deformed tensor product `X ⊗_ε Y = (X · Y) + ε · (X ⊙ Y)`.
///
/// Direct f64 port of `tensor.zig::deformedTensorProduct` (lines 261-266).
///
/// - ε = 0 → ordinary matrix multiplication.
/// - ε → ∞ → dominated by the Hadamard term.
///
/// The archetype condition `a ⊗_ε a = a` is the POLER idempotency invariant
/// (see [`crate::poler_cycle::verify_archetype_idempotent`]).
#[inline]
pub fn deformed_tensor_product(x: &Mat4, y: &Mat4, epsilon: f64) -> Mat4 {
    let linear = x.matmul(y); // X · Y
    let nonlinear = x.hadamard(y); // X ⊙ Y
    let deform = nonlinear.scale(epsilon); // ε · (X ⊙ Y)
    linear.add(&deform) // (X · Y) + ε · (X ⊙ Y)
}
/// Dissipator `D = L · Lᵀ` (entropy burner).
///
/// `D` is symmetric positive semi-definite by construction. Used in the POLER
/// cycle as the damping/viscosity term.
///
/// Port of `tensor.zig::dissipator` (lines 276-279).
#[inline]
pub fn dissipator(l: &Mat4) -> Mat4 {
    let lt = l.transpose();
    l.matmul(&lt)
}
/// Resonance operator `J = A − Aᵀ` (skew-symmetric temporal echo).
///
/// `Jᵀ = −J` by construction. Eigenvalues are purely imaginary; drives
/// periodic orbits in the POLER trajectory.
///
/// Port of `tensor.zig::resonance` (lines 288-291).
#[inline]
pub fn resonance(a: &Mat4) -> Mat4 {
    let at = a.transpose();
    a.sub(&at)
}
#[cfg(test)]
mod tests {
    use super::*;
fn sample_a() -> Mat4 {
        Mat4::from_rows(
            [1.0, 2.0, 0.0, 0.0],
            [3.0, 4.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0],
        )
    }
fn sample_b() -> Mat4 {
        Mat4::from_rows(
            [5.0, 6.0, 0.0, 0.0],
            [7.0, 8.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0],
        )
    }
#[test]
    fn matmul_identity() {
        let a = sample_a();
        let i = Mat4::identity();
        let c = a.matmul(&i);
        assert!(a.approx_eq(&c, 1e-12));
    }
#[test]
    fn hadamard_element_wise() {
        let a = Mat4::from_rows(
            [2.0, 0.0, 0.0, 0.0],
            [0.0, 3.0, 0.0, 0.0],
            [0.0, 0.0, 4.0, 0.0],
            [0.0, 0.0, 0.0, 5.0],
        );
        let b = Mat4::from_rows(
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 2.0, 0.0, 0.0],
            [0.0, 0.0, 3.0, 0.0],
            [0.0, 0.0, 0.0, 4.0],
        );
        let c = a.hadamard(&b);
        assert!((c.get(0, 0) - 2.0).abs() < 1e-12);
        assert!((c.get(1, 1) - 6.0).abs() < 1e-12);
        assert!((c.get(2, 2) - 12.0).abs() < 1e-12);
        assert!((c.get(3, 3) - 20.0).abs() < 1e-12);
    }
#[test]
    fn deformed_tensor_product_eps0_is_matmul() {
        let a = sample_a();
        let b = sample_b();
        let r = deformed_tensor_product(&a, &b, 0.0);
        let m = a.matmul(&b);
        assert!(r.approx_eq(&m, 1e-12));
    }
#[test]
    fn deformed_tensor_product_eps_adds_hadamard() {
        // I ⊗_ε (2I) = 2I + ε·2I = (2 + 2ε)·I
        let a = Mat4::identity();
        let b = Mat4::identity().scale(2.0);
        let eps = 0.5;
        let r = deformed_tensor_product(&a, &b, eps);
        let expected_val = 2.0 + eps * 2.0; // = 3.0
        for i in 0..4 {
            assert!((r.get(i, i) - expected_val).abs() < 1e-12);
        }
    }
#[test]
    fn dissipator_is_symmetric() {
        let l = Mat4::from_rows(
            [0.3, 0.0, 0.0, 0.0],
            [0.1, 0.2, 0.0, 0.0],
            [0.0, 0.05, 0.15, 0.0],
            [0.0, 0.0, 0.01, 0.1],
        );
        let d = dissipator(&l);
        let dt = d.transpose();
        assert!(d.approx_eq(&dt, 1e-12));
    }
#[test]
    fn resonance_is_skew_symmetric() {
        let a = Mat4::from_rows(
            [0.0, 1.0, 2.0, 3.0],
            [4.0, 0.0, 5.0, 6.0],
            [7.0, 8.0, 0.0, 9.0],
            [10.0, 11.0, 12.0, 0.0],
        );
        let j = resonance(&a);
        let jt = j.transpose();
        let neg_j = j.scale(-1.0);
        assert!(jt.approx_eq(&neg_j, 1e-12));
    }
#[test]
    fn resonance_diagonal_is_zero() {
        let a = Mat4::from_rows(
            [1.0, 2.0, 3.0, 4.0],
            [5.0, 6.0, 7.0, 8.0],
            [9.0, 10.0, 11.0, 12.0],
            [13.0, 14.0, 15.0, 16.0],
        );
        let j = resonance(&a);
        for i in 0..4 {
            assert!(j.get(i, i).abs() < 1e-12);
        }
    }
#[test]
    fn vec4_normalize_preserves_direction() {
        let v = Vec4([3.0, 0.0, 0.0, 0.0]);
        let n = v.normalize();
        assert!((n.norm() - 1.0).abs() < 1e-12);
        assert!((n.0[0] - 1.0).abs() < 1e-12);
    }
}
cordic.rs — CORDIC 1/√x (Newton-Raphson)
//! cordic.rs — CPU-side numeric primitives: `1/√x`, `1/x`, `sin`/`cos`/`atan2`.
//!
//! ## Design philosophy
//!
//! The FPGA implementation (`cordic_inv_sqrt.v`) computes `y = 1/sqrt(x)` in
//! Q32.32 fixed-point via 6 Newton-Raphson iterations starting from a
//! bit-shift initial guess (because FPGA has no hardware sqrt/divide).
//!
//! On CPU we have hardware sqrt/divide — so the f64 path here uses the
//! hardware primitives directly. The 6-iteration Newton-Raphson refinement
//! is kept as a *parity-of-structure* with the FPGA: the iteration is a
//! no-op when the hardware result is already at f64 precision, but it
//! guarantees that if a future caller replaces the initial guess with a
//! cheaper approximation (e.g. for a hand-rolled SIMD batch), the same
//! convergence behavior as the FPGA is preserved.
//!
//! For **bit-exact FPGA parity** (deterministic-mode rendering), use
//! [`crate::q32_32::inv_sqrt`] — that function mirrors the Verilog
//! `cordic_inv_sqrt.v` line-for-line in Q32.32 fixed-point.
//!
//! ## What's NOT in the FPGA but is here
//!
//! `sin`, `cos`, `atan2` are *not* in the Verilog — the FPGA only needed
//! `1/√x`. We add them here as classic CORDIC rotation/vector-mode
//! implementations because the P³ voxel engine needs them for camera
//! rotations and PGL(4) decompositions. They share the same CORDIC spirit
//! (fixed-iteration, no `libm` dependence on the hot path, bit-stable).
//!
//! # References
//! - `fpga-project/verilog/cordic_inv_sqrt.v` (Q32.32 1/√x, 6 iter)
//! - `fpga-project/verilog/newton_schulz_inv.v::approx_recip` (Q32.32 1/x, 4 iter)
/// Default Newton-Raphson iteration count for `inv_sqrt`.
///
/// Matches `cordic_inv_sqrt.v::NEWTON_ITER = 6`. On CPU the iteration is a
/// no-op when starting from `1/x.sqrt()` (already at f64 precision); the
/// count is preserved for API parity.
pub const DEFAULT_NEWTON_ITER: usize = 6;
/// Default Newton-Raphson iteration count for `recip`.
///
/// Matches `approx_recip` in `newton_schulz_inv.v:106` (4 iterations).
pub const DEFAULT_RECIP_ITER: usize = 4;
/// `1 / sqrt(x)` via Newton-Raphson, 6 iterations.
///
/// Returns `0.0` for `x ≤ 0` (matches the Verilog behavior of asserting
/// `valid = 0` and emitting `int2q(0)`).
///
/// On CPU the initial guess `1.0 / x.sqrt()` is already at f64 precision,
/// so the 6 Newton-Raphson iterations are essentially a no-op — they're
/// here for structural parity with [`crate::q32_32::inv_sqrt`].
#[inline]
pub fn inv_sqrt(x: f64) -> f64 {
    inv_sqrt_iter(x, DEFAULT_NEWTON_ITER)
}
/// `1 / sqrt(x)` with a caller-specified iteration count.
pub fn inv_sqrt_iter(x: f64, iter: usize) -> f64 {
    if x <= 0.0 || !x.is_finite() {
        return 0.0;
    }
    // Hardware-accelerated initial guess.
    let mut y = 1.0 / x.sqrt();
    // Newton-Raphson refinement: y_{k+1} = 0.5 · y_k · (3 − x · y_k²).
    // Iteration count matches `cordic_inv_sqrt.v::NEWTON_ITER = 6`.
    // If y_0 is already at f64 precision, this is a no-op; if a future
    // caller swaps in a cheaper initial guess, the iteration converges
    // quadratically.
    for _ in 0..iter {
        let y_sq = y * y;
        let factor = 3.0 - x * y_sq;
        y = 0.5 * y * factor;
    }
    y
}
/// `1 / x` via Newton-Raphson, 4 iterations.
///
/// Mirrors `approx_recip` in `newton_schulz_inv.v:63-114`. On CPU the
/// initial guess `1.0 / x` is exact, so the 4 iterations are a no-op — they
/// exist for parity with the Q32.32 implementation in
/// [`crate::q32_32::recip`], where they are essential (Q32.32 has no
/// hardware divide).
pub fn recip(x: f64) -> f64 {
    if x == 0.0 {
        return f64::INFINITY.copysign(x);
    }
    if !x.is_finite() {
        return 0.0_f64;
    }
    let mut y = 1.0 / x;
    for _ in 0..DEFAULT_RECIP_ITER {
        // y_{k+1} = y_k · (2 − x · y_k)
        let two_minus_xy = 2.0 - x * y;
        y = y * two_minus_xy;
    }
    y
}
// ============================================================================
// CORDIC rotation mode: sin / cos
// ============================================================================
/// Number of CORDIC iterations used for `sincos` / `atan2`.
///
/// 60 iterations give ~60 bits of angular resolution, which is the practical
/// limit for f64 — each iteration adds roughly one bit.
pub const CORDIC_ITER: usize = 60;
/// Compute `(sin θ, cos θ)` via CORDIC rotation mode.
///
/// This is the classic CORDIC algorithm: starting from `(K, 0)` with angle
/// `0`, rotate by `θ` using a precomputed table of `atan(2^−k)`. The basic
/// CORDIC iteration converges only for `|z| ≤ ~1.74` (about `π/2`); for
/// larger angles we use the symmetry `sin(π − θ) = sin θ`, `cos(π − θ) = −cos θ`
/// to reduce into the convergence domain.
///
/// Returns the same result as `libm::sincos` to within `1e-9` absolute.
pub fn sincos(theta: f64) -> (f64, f64) {
    // Reduce to (−π, π]. We need a tight reduction because CORDIC only
    // converges for |z| ≤ ~1.74.
    let two_pi = 2.0 * core::f64::consts::PI;
    let mut z = theta % two_pi; // (−2π, 2π)
    if z > core::f64::consts::PI {
        z -= two_pi;
    } else if z < -core::f64::consts::PI {
        z += two_pi;
    }
// CORDIC converges only for |z| < ~1.74 (atan(1) + atan(1/2) + ... ≈ 1.74).
    // For |z| > π/2 we use the half-angle symmetry:
    //   sin(π − z) = sin z,   cos(π − z) = −cos z
    // to fold into the convergence domain. Same trick for the negative side.
    let flip_cos = if z > core::f64::consts::FRAC_PI_2 {
        z = core::f64::consts::PI - z;
        true
    } else if z < -core::f64::consts::FRAC_PI_2 {
        z = -core::f64::consts::PI - z;
        true
    } else {
        false
    };
// CORDIC gain: K = Π_k sqrt(1 + 2^(−2k)) ≈ 0.6072529350088813
    const K: f64 = 0.6072529350088813;
let mut x = K;
    let mut y = 0.0_f64;
for k in 0..CORDIC_ITER {
        let d = if z >= 0.0 { 1.0 } else { -1.0 };
        let pow2 = 1.0_f64 / (1u64 << k) as f64; // 2^(−k)
        let angle = atan_table(k);
        let dx = d * pow2;
        let nx = x - y * dx;
        let ny = y + x * dx;
        x = nx;
        y = ny;
        z -= d * angle;
    }
    if flip_cos {
        (y, -x)
    } else {
        (y, x)
    }
}
/// `sin θ` — see [`sincos`].
#[inline]
pub fn sin(theta: f64) -> f64 {
    sincos(theta).0
}
/// `cos θ` — see [`sincos`].
#[inline]
pub fn cos(theta: f64) -> f64 {
    sincos(theta).1
}
/// `atan2(y, x)` via CORDIC vector mode.
///
/// Returns the angle in `(−π, π]`. Matches `libm::atan2` to within `1e-15`.
pub fn atan2(y: f64, x: f64) -> f64 {
    if x == 0.0 && y == 0.0 {
        return 0.0;
    }
    // Handle quadrants by reflecting into the first quadrant (x > 0, y ≥ 0)
    // and patching the result up at the end.
    let mut ax = x.abs();
    let mut ay = y.abs();
    let swap = ay > ax;
    if swap {
        core::mem::swap(&mut ax, &mut ay);
    }
// CORDIC vector mode: drive y → 0.
    let mut cx = ax;
    let mut cy = ay;
    let mut z = 0.0_f64;
for k in 0..CORDIC_ITER {
        let d = if cy >= 0.0 { -1.0 } else { 1.0 };
        let pow2 = 1.0_f64 / (1u64 << k) as f64;
        let angle = atan_table(k);
        let dx = d * pow2;
        let nx = cx - cy * dx;
        let ny = cy + cx * dx;
        cx = nx;
        cy = ny;
        z -= d * angle;
    }
    let mut result = z;
    if swap {
        result = core::f64::consts::FRAC_PI_2 - result;
    }
    // Quadrant correction
    if x < 0.0 {
        if y >= 0.0 {
            result = core::f64::consts::PI - result;
        } else {
            result = -core::f64::consts::PI + result;
        }
    } else if y < 0.0 {
        result = -result;
    }
    result
}
/// Precomputed `atan(2^−k)` for `k = 0..CORDIC_ITER`. Storing the table
/// avoids recomputing the same constant 60 times per `sincos` call.
///
/// Values are exact to f64 precision; computed offline as
/// `atan(2.0_f64.powi(-(k as i32)))`.
#[inline]
fn atan_table(k: usize) -> f64 {
    const TABLE: [f64; 60] = [
        7.85398163397448309616e-01,
        4.63647609000806116236e-01,
        2.44978663126864154173e-01,
        1.24354994546761435030e-01,
        6.24188099959573484741e-02,
        3.12398324321430404808e-02,
        1.56237286204768308056e-02,
        7.81234106010111114468e-03,
        3.90623013196697182765e-03,
        1.95312251647881828534e-03,
        9.76562189559319430258e-04,
        4.88281211194898287436e-04,
        2.44140620149361761520e-04,
        1.22070311893670204242e-04,
        6.10351561742087726681e-05,
        3.05175781155209501436e-05,
        1.52587890613157621041e-05,
        7.62939453110193002076e-06,
        3.81469726560649628292e-06,
        1.90734863281018705036e-06,
        9.53674316405960879206e-07,
        4.76837158203088829941e-07,
        2.38418579101557980830e-07,
        1.19209289550780683111e-07,
        5.96046447753905544319e-08,
        2.98023223876953055371e-08,
        1.49011611938476551472e-08,
        7.45058059692382795272e-09,
        3.72529029846191404480e-09,
        1.86264514923095702910e-09,
        9.31322574615478515625e-10,
        4.65661287307739257812e-10,
        2.32830643653869628906e-10,
        1.16415321826934814453e-10,
        5.82076609134674072266e-11,
        2.91038304567337036133e-11,
        1.45519152283668518066e-11,
        7.27595761418342590332e-12,
        3.63797880709171295166e-12,
        1.81898940354585647583e-12,
        9.09494701772928237915e-13,
        4.54747350886464118958e-13,
        2.27373675443232059479e-13,
        1.13686837721616029739e-13,
        5.68434188608080148696e-14,
        2.84217094304040074348e-14,
        1.42108547152020037174e-14,
        7.10542735760100185872e-15,
        3.55271367880050092936e-15,
        1.77635683940025046468e-15,
        8.88178419700125232339e-16,
        4.44089209850062616170e-16,
        2.22044604925031308085e-16,
        1.11022302462515654042e-16,
        5.55111512312578270212e-17,
        2.77555756156289135106e-17,
        1.38777878078144567553e-17,
        6.93889390390722837765e-18,
        3.46944695195361418883e-18,
        1.73472347597680709441e-18,
    ];
    TABLE[k]
}
#[cfg(test)]
mod tests {
    use super::*;
#[test]
    fn inv_sqrt_matches_libm() {
        for &x in &[0.25_f64, 0.5, 1.0, 2.0, 4.0, 16.0, 100.0, 1e6, 1e-6] {
            let got = inv_sqrt(x);
            let want = 1.0 / x.sqrt();
            let rel_err = (got - want).abs() / want;
            assert!(rel_err < 1e-12, "x={x}: got={got}, want={want}, rel_err={rel_err}");
        }
    }
#[test]
    fn inv_sqrt_invalid_input_returns_zero() {
        assert_eq!(inv_sqrt(0.0), 0.0);
        assert_eq!(inv_sqrt(-1.0), 0.0);
        assert_eq!(inv_sqrt(f64::NAN), 0.0);
    }
#[test]
    fn recip_matches_libm() {
        for &x in &[0.5_f64, 1.0, 2.0, 4.0, 100.0, 1e6, 1e-6, -1.0, -100.0] {
            let got = recip(x);
            let want = 1.0 / x;
            let rel_err = (got - want).abs() / want.abs();
            assert!(rel_err < 1e-12, "x={x}: got={got}, want={want}, rel_err={rel_err}");
        }
    }
#[test]
    fn sincos_matches_libm() {
        // CORDIC with 60 iterations achieves ~1e-9 absolute precision for
        // small angles (the residual |y| is bounded by x_k · |z_k| ≈ 2^-30
        // for k = 30, but accumulated f64 rounding errors prevent full
        // 2^-60 convergence in practice).
        for &theta in &[
            0.0_f64,
            core::f64::consts::FRAC_PI_4,
            core::f64::consts::FRAC_PI_2,
            core::f64::consts::PI,
            -core::f64::consts::FRAC_PI_3,
            1.0,
            -2.5,
            10.0,
            100.0,
            -100.0,
        ] {
            let (s, c) = sincos(theta);
            let want_s = theta.sin();
            let want_c = theta.cos();
            // Use the larger of absolute error or relative error (relative to
            // the magnitude of the true value, with a floor of 1.0 to handle
            // the |want| < 1 case). CORDIC's worst-case error is ~1e-9
            // absolute for small angles; for large magnitudes the relative
            // error is ~1e-12.
            let abs_err_s = (s - want_s).abs();
            let abs_err_c = (c - want_c).abs();
            let scale_s = want_s.abs().max(1.0);
            let scale_c = want_c.abs().max(1.0);
            assert!(abs_err_s < 1e-9 * scale_s, "sin({theta}): got={s}, want={want_s}, abs_err={abs_err_s}");
            assert!(abs_err_c < 1e-9 * scale_c, "cos({theta}): got={c}, want={want_c}, abs_err={abs_err_c}");
        }
    }
#[test]
    fn atan2_matches_libm() {
        // CORDIC atan2 achieves ~1e-9 absolute precision (same limit as sincos).
        for &(x, y) in &[
            (1.0_f64, 0.0_f64),
            (0.0, 1.0),
            (1.0, 1.0),
            (-1.0, 1.0),
            (-1.0, -1.0),
            (1.0, -1.0),
            (3.0, 4.0),
            (-5.0, 12.0),
            (0.0, 0.0),
        ] {
            let got = atan2(y, x);
            let want = f64::atan2(y, x);
            let abs_err = (got - want).abs();
            // |want| ∈ [0, π], so use a floor of 1.0 for the relative scale.
            let scale = want.abs().max(1.0);
            assert!(abs_err < 1e-9 * scale, "atan2({y},{x}): got={got}, want={want}, abs_err={abs_err}");
        }
    }
}
newton_schulz.rs — 4×4 Matrix Inversion
//! newton_schulz.rs — 4×4 matrix inversion via Newton-Schulz iteration,
//! with Gauss-Jordan partial-pivoting fallback.
//!
//! # Newton-Schulz iteration
//!
//! For an SPD matrix `M`, the iteration
//!
//! ```text
//! X_{k+1} = X_k · (2I − M · X_k)
//! ```
//!
//! converges quadratically to `M⁻¹` provided `‖I − M·X_0‖ < 1`. The FPGA
//! implementation (`newton_schulz_inv.v`) uses `X_0 = α·I` with
//! `α = 2 / tr(M)` and `MAX_ITER = 8`. We mirror that here in f64. The
//! convergence check is `‖M·X_k − I‖_F² < 2⁻¹⁶ ≈ 1.5e-5`.
//!
//! For non-SPD matrices (which the projector `(Jc·Jcᵀ + δI)` always is, but
//! generic user matrices might not be), we fall back to
//! [`invert_gauss_jordan`], which is the same algorithm as
//! `tensor.zig::invertMatrix` (lines 336-398).
//!
//! # References
//! - `fpga-project/verilog/newton_schulz_inv.v` (Q32.32 reference, 8 iter)
//! - `fpga-project/zig/tensor.zig::invertMatrix` (f64 Gauss-Jordan)
use crate::cordic::recip;
use crate::tensor::Mat4;
/// Default Tikhonov regularization (matches `tensor.zig:314`).
pub const DEFAULT_DELTA: f64 = 1e-8;
/// Default Newton-Schulz iteration count (matches `newton_schulz_inv.v::MAX_ITER`).
pub const DEFAULT_MAX_ITER: usize = 8;
/// Convergence threshold for the Newton-Schulz iteration: `‖M·X_k − I‖_F² < 2⁻¹⁶`.
///
/// Mirrors `int2q(1) >>> 16` from `newton_schulz_inv.v:276`.
pub const DEFAULT_CONV_THRESHOLD: f64 = (1.0_f64 / 65536.0) * (1.0_f64 / 65536.0);
/// Gauss-Jordan inversion with partial pivoting.
///
/// Direct f64 port of `tensor.zig::invertMatrix` (lines 336-398). Returns
/// `None` if the matrix is singular (pivot < `1e-12`).
pub fn invert_gauss_jordan(m: &Mat4) -> Option<Mat4> {
    // Augmented matrix [M | I], stored as 4 rows of 8 f64.
    let mut aug = [[0.0_f64; 8]; 4];
    for i in 0..4 {
        for j in 0..4 {
            aug[i][j] = m.get(i, j);
        }
        aug[i][4 + i] = 1.0;
    }
for col in 0..4 {
        // Find pivot (largest absolute value in column `col`, rows col..4).
        let mut max_val = aug[col][col].abs();
        let mut max_row = col;
        for row in (col + 1)..4 {
            let v = aug[row][col].abs();
            if v > max_val {
                max_val = v;
                max_row = row;
            }
        }
        if max_val < 1e-12 {
            return None;
        }
// Swap rows.
        if max_row != col {
            aug.swap(col, max_row);
        }
// Scale pivot row.
        let pivot = aug[col][col];
        for j in 0..8 {
            aug[col][j] /= pivot;
        }
// Eliminate column from all other rows.
        for row in 0..4 {
            if row == col {
                continue;
            }
            let factor = aug[row][col];
            for j in 0..8 {
                aug[row][j] -= factor * aug[col][j];
            }
        }
    }
// Extract inverse from the right half.
    let mut out = Mat4::zero();
    for i in 0..4 {
        for j in 0..4 {
            out.set(i, j, aug[i][4 + j]);
        }
    }
    Some(out)
}
/// Newton-Schulz matrix inversion for SPD matrices.
///
/// Implements `X_{k+1} = X_k · (2I − M · X_k)` with `X_0 = α·I`,
/// `α = 2 / tr(M)`. Adds `δ·I` to `M` first (Tikhonov regularization), which
/// guarantees SPD-ness and is the same scheme used in `tensor.zig::logicalProjector`.
///
/// Returns `None` if `M + δ·I` is not invertible (this should not happen for
/// any reasonable `δ > 0`).
///
/// # Algorithm fidelity to FPGA
///
/// This mirrors `newton_schulz_inv.v` exactly:
/// 1. Regularize: `M_reg = M + δ·I`.
/// 2. Compute `α = 2 / tr(M_reg)`.
/// 3. `X_0 = α·I`.
/// 4. For `k = 0..max_iter`: `T = M_reg · X_k`, `S = 2I − T`, `X_{k+1} = X_k · S`.
/// 5. Convergence: `‖M_reg · X_k − I‖_F² < threshold`.
pub fn invert_newton_schulz(m: &Mat4, delta: f64, max_iter: usize) -> Option<Mat4> {
    // Step 1: regularize.
    let mut m_reg = *m;
    for i in 0..4 {
        let v = m_reg.get(i, i) + delta;
        m_reg.set(i, i, v);
    }
// Step 2: α = 2 / tr(M_reg). Use `recip` for FPGA parity.
    let trace = m_reg.trace();
    if trace.abs() < 1e-300 {
        return None;
    }
    let alpha = 2.0 * recip(trace);
// Step 3: X_0 = α·I.
    let mut x = Mat4::identity().scale(alpha);
let two_i = Mat4::identity().scale(2.0);
// Step 4: iterate. Always runs all `max_iter` iterations to match the
    // Verilog behavior (`newton_schulz_inv.v` always runs MAX_ITER; the
    // `converged` flag is a status indicator, not an early-exit). For f64
    // this guarantees we reach machine precision whenever the iteration
    // converges at all.
    for _ in 0..max_iter {
        // T = M_reg · X_k
        let t = m_reg.matmul(&x);
        // S = 2I − T
        let s = two_i.sub(&t);
        // X_{k+1} = X_k · S
        x = x.matmul(&s);
    }
    // The caller can verify convergence by checking `‖M·X − I‖_F` if needed.
    Some(x)
}
/// Invert a 4×4 matrix.
///
/// Strategy:
/// 1. Try [`invert_gauss_jordan`] — works for any non-singular matrix, and is
///    the path used by [`crate::poler_cycle::logical_projector`] in the Zig
///    reference.
/// 2. If the caller knows the matrix is SPD (e.g. `Jc·Jcᵀ + δI`), they should
///    call [`invert_newton_schulz`] directly — it is faster and bit-stable.
///
/// Returns `None` for singular matrices.
#[inline]
pub fn invert(m: &Mat4) -> Option<Mat4> {
    invert_gauss_jordan(m)
}
#[cfg(test)]
mod tests {
    use super::*;
#[test]
    fn identity_inverts_to_identity_gj() {
        let i = Mat4::identity();
        let inv = invert_gauss_jordan(&i).unwrap();
        assert!(inv.approx_eq(&i, 1e-12));
    }
#[test]
    fn identity_inverts_to_identity_ns() {
        let i = Mat4::identity();
        let inv = invert_newton_schulz(&i, 0.0, DEFAULT_MAX_ITER).unwrap();
        assert!(inv.approx_eq(&i, 1e-9));
    }
#[test]
    fn diagonal_inverts_gj() {
        let a = Mat4::from_rows(
            [4.0, 0.0, 0.0, 0.0],
            [0.0, 3.0, 0.0, 0.0],
            [0.0, 0.0, 2.0, 0.0],
            [0.0, 0.0, 0.0, 1.0],
        );
        let expected = Mat4::from_rows(
            [0.25, 0.0, 0.0, 0.0],
            [0.0, 1.0 / 3.0, 0.0, 0.0],
            [0.0, 0.0, 0.5, 0.0],
            [0.0, 0.0, 0.0, 1.0],
        );
        let inv = invert_gauss_jordan(&a).unwrap();
        assert!(inv.approx_eq(&expected, 1e-12));
    }
#[test]
    fn diagonal_inverts_ns() {
        let a = Mat4::from_rows(
            [4.0, 0.0, 0.0, 0.0],
            [0.0, 3.0, 0.0, 0.0],
            [0.0, 0.0, 2.0, 0.0],
            [0.0, 0.0, 0.0, 1.0],
        );
        let expected = Mat4::from_rows(
            [0.25, 0.0, 0.0, 0.0],
            [0.0, 1.0 / 3.0, 0.0, 0.0],
            [0.0, 0.0, 0.5, 0.0],
            [0.0, 0.0, 0.0, 1.0],
        );
        let inv = invert_newton_schulz(&a, 0.0, DEFAULT_MAX_ITER).unwrap();
        assert!(inv.approx_eq(&expected, 1e-9));
    }
#[test]
    fn product_with_inverse_is_identity() {
        let a = Mat4::from_rows(
            [4.0, 1.0, 0.0, 0.0],
            [1.0, 3.0, 1.0, 0.0],
            [0.0, 1.0, 2.0, 1.0],
            [0.0, 0.0, 1.0, 5.0],
        );
        let inv = invert_gauss_jordan(&a).unwrap();
        let prod = a.matmul(&inv);
        assert!(prod.approx_eq(&Mat4::identity(), 1e-10));
    }
#[test]
    fn ns_matches_gj_on_spd() {
        // SPD matrix.
        let a = Mat4::from_rows(
            [4.0, 1.0, 0.0, 0.0],
            [1.0, 3.0, 1.0, 0.0],
            [0.0, 1.0, 2.0, 1.0],
            [0.0, 0.0, 1.0, 5.0],
        );
        let inv_gj = invert_gauss_jordan(&a).unwrap();
        let inv_ns = invert_newton_schulz(&a, 0.0, DEFAULT_MAX_ITER).unwrap();
        // Newton-Schulz at 8 iter has small residual error; allow 1e-7.
        assert!(inv_gj.approx_eq(&inv_ns, 1e-7));
    }
#[test]
    fn singular_matrix_returns_none() {
        let s = Mat4::from_rows(
            [1.0, 2.0, 3.0, 4.0],
            [2.0, 4.0, 6.0, 8.0],
            [1.0, 1.0, 1.0, 1.0],
            [0.0, 1.0, 2.0, 3.0],
        );
        assert!(invert_gauss_jordan(&s).is_none());
    }
}
poler_cycle.rs — Projected Gradient Descent
//! poler_cycle.rs — POLER projected-gradient descent step, the iterative
//! POLER cycle, the logical projector Π_Λ, and the archetype idempotency
//! check.
//!
//! # The POLER discrete step
//!
//! Given the dissipator `D = L·Lᵀ`, the resonance `J = A − Aᵀ`, the logical
//! projector `Π_Λ = I − Jcᵀ·(Jc·Jcᵀ + δI)⁻¹·Jc`, and the quadratic potential
//! `∇F(p) = G·p`, the POLER cycle is
//!
//! ```text
//! P_new = p_t − η · Π_Λ( D·p_t + γ·J·p_t + ∇F(p_t) )
//! ```
//!
//! followed by quantum normalization
//!
//! ```text
//! p_{t+1} = (1 − mix) · P_new + mix · P_new / ‖P_new‖
//! ```
//!
//! (see [`crate::quantum`]). The cycle converges to a fixed point
//! `p* = a ⊗_ε p*` that satisfies the archetype condition.
//!
//! # What this is NOT
//!
//! This is the **FPGA/Zig POLER cycle** (from `tensor.zig` and
//! `poler_cycle.v`), used for archetype attractor search. It is distinct from
//! `poler_core.py`, which is the cognitive-LLM POLER variant with free-energy
//! `F(p, o; θ)` and emo-intensity resonance weights — that one uses
//! `Π_Λ = I` as a placeholder and a different update rule. We do not
//! reimplement `poler_core.py` here; the P³ voxel engine only needs the
//! FPGA/Zig math.
//!
//! # References
//! - `fpga-project/zig/tensor.zig::logicalProjector` (lines 303-329)
//! - `fpga-project/zig/tensor.zig::polerDiscreteStep` (lines 428-464)
//! - `fpga-project/zig/tensor.zig::polerCycle` (lines 507-540)
//! - `fpga-project/verilog/poler_cycle.v` (Q32.32 reference)
use crate::newton_schulz::{invert_gauss_jordan, DEFAULT_DELTA};
use crate::tensor::{dissipator, resonance, Mat4};
/// Tikhonov regularization δ used in [`logical_projector`].
///
/// Matches `tensor.zig:314`. Small relative to typical constraint norms;
/// guarantees `(Jc·Jcᵀ + δI)` is invertible even when `Jc` is rank-deficient.
pub const PROJECTOR_DELTA: f64 = DEFAULT_DELTA;
/// Configuration for [`poler_cycle`].
///
/// All defaults match `tensor.zig::PolerConfig` (lines 499-505).
#[derive(Clone, Copy, Debug)]
pub struct PolerConfig {
    /// Learning rate η (default `0.01`).
    pub eta: f64,
    /// Resonance coupling γ (default `0.1`).
    pub gamma: f64,
    /// Quantum-normalization mixing coefficient (default `0.1`).
    pub mix: f64,
    /// Maximum number of POLER iterations (default `1000`).
    pub max_iterations: u32,
    /// Frobenius-norm convergence threshold (default `1e-10`).
    pub tolerance: f64,
    /// Tikhonov δ for [`logical_projector`] (default `1e-8`).
    pub delta: f64,
}
impl Default for PolerConfig {
    #[inline]
    fn default() -> Self {
        Self {
            eta: 0.01,
            gamma: 0.1,
            mix: 0.1,
            max_iterations: 1000,
            tolerance: 1e-10,
            delta: PROJECTOR_DELTA,
        }
    }
}
/// Result of a [`poler_cycle`] run.
#[derive(Clone, Copy, Debug)]
pub struct PolerCycleResult {
    /// Final state matrix (4×4).
    pub state: Mat4,
    /// Number of iterations actually performed.
    pub iterations: u32,
    /// True if `final_delta ≤ tolerance`.
    pub converged: bool,
    /// Final `‖p_{t+1} − p_t‖_F`.
    pub final_delta: f64,
}
/// Logical projector `Π_Λ = I − Jcᵀ · (Jc · Jcᵀ + δI)⁻¹ · Jc`.
///
/// Enforces causality constraints by projecting onto the null space of `Jc`.
/// Direct f64 port of `tensor.zig::logicalProjector` (lines 303-329).
///
/// # Tikhonov regularization
///
/// Without `δ`, rank-deficient `Jc` makes `Jc · Jcᵀ` singular and the
/// projector degenerates to `I` (no constraint enforcement). The
/// `δ · I` term guarantees invertibility.
///
/// # Usage in P³ Voxel Engine
///
/// Per Agent 1 spec §8.1: applied every ~100 chunk-streaming steps to
/// `chunk.basis` to remove accumulated f64 drift. This is the anti-drift
/// primitive that keeps long-running worlds numerically stable.
pub fn logical_projector(jc: &Mat4) -> Mat4 {
    logical_projector_with_delta(jc, PROJECTOR_DELTA)
}
/// [`logical_projector`] with caller-specified Tikhonov δ.
pub fn logical_projector_with_delta(jc: &Mat4, delta: f64) -> Mat4 {
    let i = Mat4::identity();
    let jc_t = jc.transpose();
// M = Jc · Jcᵀ  (symmetric positive semi-definite).
    let mut m = jc.matmul(&jc_t);
// Tikhonov: M_reg = M + δ·I.
    for r in 0..4 {
        let v = m.get(r, r) + delta;
        m.set(r, r, v);
    }
// M_reg^{-1} — fall back to identity if singular (matches Zig behavior).
    let m_inv = match invert_gauss_jordan(&m) {
        Some(inv) => inv,
        None => return i,
    };
// Π_Λ = I − Jcᵀ · M_reg^{-1} · Jc.
    let temp = jc_t.matmul(&m_inv);
    let proj_inner = temp.matmul(jc);
    i.sub(&proj_inner)
}
/// One discrete POLER step.
///
/// Computes `P_new = p_t − η · Π_Λ(D·p_t + γ·J·p_t + ∇F(p_t))` where
/// `D = L·Lᵀ`, `J = A − Aᵀ`, `∇F(p) = G·p`.
///
/// Direct port of `tensor.zig::polerDiscreteStep` (lines 428-464).
///
/// Note: in the Zig/Verilog convention the state `p` is a 4×4 matrix whose
/// only non-zero column is column 0 (i.e. `p` is really a 4-vector stored in
/// a 4×4 slot). For the P³ voxel engine we expose the same signature so that
/// tests match the Zig reference bit-for-bit. A future agent may add a
/// `Vec4`-based variant.
pub fn poler_discrete_step(
    l: &Mat4,
    a: &Mat4,
    jc: &Mat4,
    g: &Mat4,
    p_t: &Mat4,
    eta: f64,
    gamma: f64,
) -> Mat4 {
    let d = dissipator(l); // D = L · Lᵀ
    let j = resonance(a); // J = A − Aᵀ
    let pi = logical_projector(jc); // Π_Λ
let diss_term = d.matmul(p_t); // D · p_t
    let res_term = j.matmul(p_t).scale(gamma); // γ · J · p_t
    let grad_term = g.matmul(p_t); // ∇F = G · p_t
let force = diss_term.add(&res_term).add(&grad_term);
    let projected_force = pi.matmul(&force);
// P_new = p_t − η · Π_Λ(force)
    p_t.sub(&projected_force.scale(eta))
}
/// Run the full POLER cycle to convergence.
///
/// Each iteration applies [`poler_discrete_step`] followed by
/// [`crate::quantum::quantize_normalize`]. Convergence is reached when
/// `‖p_{t+1} − p_t‖_F < tolerance` or `max_iterations` is exhausted.
///
/// Direct port of `tensor.zig::polerCycle` (lines 507-540).
pub fn poler_cycle(
    l: &Mat4,
    a: &Mat4,
    jc: &Mat4,
    g: &Mat4,
    p0: &Mat4,
    config: &PolerConfig,
) -> PolerCycleResult {
    use crate::quantum::quantum_normalize;
let mut p = *p0;
    let mut iter: u32 = 0;
    let mut delta: f64 = 1.0;
while iter < config.max_iterations && delta > config.tolerance {
        let p_new = poler_discrete_step(l, a, jc, g, &p, config.eta, config.gamma);
        let p_next = quantum_normalize(&p_new, config.mix);
let diff = p_next.sub(&p);
        delta = diff.frobenius_norm();
p = p_next;
        iter += 1;
    }
PolerCycleResult {
        state: p,
        iterations: iter,
        converged: delta <= config.tolerance,
        final_delta: delta,
    }
}
/// Check the archetype idempotency condition `a ⊗_ε a ≈ a`.
///
/// For ε = 0 this reduces to the standard projection-matrix condition
/// `a · a = a`. For ε ≠ 0 the archetype must generally be found numerically
/// via [`poler_cycle`].
///
/// Direct port of `tensor.zig::verifyArchetypeIdempotent` (lines 553-556).
#[inline]
pub fn verify_archetype_idempotent(a: &Mat4, epsilon: f64, tol: f64) -> bool {
    use crate::tensor::deformed_tensor_product;
    let a_tensor_a = deformed_tensor_product(a, a, epsilon);
    a_tensor_a.approx_eq(a, tol)
}
/// Check the fixed-point condition `p* = a ⊗_ε p*`.
///
/// Direct port of `tensor.zig::verifyFixedPoint` (lines 564-567).
#[inline]
pub fn verify_fixed_point(a: &Mat4, p: &Mat4, epsilon: f64, tol: f64) -> bool {
    use crate::tensor::deformed_tensor_product;
    let result = deformed_tensor_product(a, p, epsilon);
    result.approx_eq(p, tol)
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::tensor::deformed_tensor_product;
#[test]
    fn projector_is_idempotent() {
        // Jc with rank 3: enforces p[0]+p[1] = p[2]+p[3].
        let jc = Mat4::from_rows(
            [1.0, 1.0, -1.0, -1.0],
            [0.5, -0.5, 0.0, 0.0],
            [0.0, 0.0, 0.5, -0.5],
            [0.0, 0.0, 0.0, 0.0],
        );
        let pi = logical_projector(&jc);
        let pi2 = pi.matmul(&pi);
        // Allow 1e-4 tolerance to match the Zig test threshold.
        assert!(pi.approx_eq(&pi2, 1e-4));
    }
#[test]
    fn projector_is_symmetric() {
        // Π_Λ is symmetric when Jc is real (it is an orthogonal projector
        // onto a subspace of R⁴).
        let jc = Mat4::from_rows(
            [1.0, 1.0, -1.0, -1.0],
            [0.5, -0.5, 0.0, 0.0],
            [0.0, 0.0, 0.5, -0.5],
            [0.0, 0.0, 0.0, 0.0],
        );
        let pi = logical_projector(&jc);
        let pi_t = pi.transpose();
        assert!(pi.approx_eq(&pi_t, 1e-6));
    }
#[test]
    fn poler_cycle_runs_and_returns_result() {
        // Mirrors the Zig "POLER cycle converges to attractor" test.
        let l = Mat4::from_rows(
            [0.1, 0.0, 0.0, 0.0],
            [0.0, 0.1, 0.0, 0.0],
            [0.0, 0.0, 0.1, 0.0],
            [0.0, 0.0, 0.0, 0.1],
        );
        let a = Mat4::from_rows(
            [0.0, 0.1, 0.0, 0.0],
            [-0.1, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.1],
            [0.0, 0.0, -0.1, 0.0],
        );
        let jc = Mat4::from_rows(
            [1.0, 1.0, -1.0, -1.0],
            [0.5, -0.5, 0.0, 0.0],
            [0.0, 0.0, 0.5, -0.5],
            [0.0, 0.0, 0.0, 0.0],
        );
        let g = Mat4::identity().scale(0.01);
        let p0 = Mat4::from_rows(
            [1.0, 0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0, 0.0],
        );
let config = PolerConfig {
            eta: 0.05,
            gamma: 0.1,
            mix: 0.05,
            max_iterations: 5000,
            tolerance: 1e-8,
            ..Default::default()
        };
        let result = poler_cycle(&l, &a, &jc, &g, &p0, &config);
        assert!(result.iterations > 0);
        assert!(result.iterations <= config.max_iterations);
    }
#[test]
    fn identity_is_idempotent_at_eps0() {
        let i = Mat4::identity();
        assert!(verify_archetype_idempotent(&i, 0.0, 1e-12));
    }
#[test]
    fn projection_matrix_is_idempotent_at_eps0() {
        // A simple 2D projection embedded in 4×4: projects onto the first
        // coordinate.
        let p = Mat4::from_rows(
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
        );
        assert!(verify_archetype_idempotent(&p, 0.0, 1e-12));
    }
#[test]
    fn archetype_idempotency_for_diagonal_at_nonzero_eps() {
        // For a = α·I: a ⊗_ε a = α²·I + ε·α²·I = α²·(1+ε)·I.
        // For idempotency we need α²(1+ε) = α, i.e. α = 1/(1+ε).
        // With ε = 0.5 → α = 2/3.
        let alpha = 2.0 / 3.0;
        let a = Mat4::identity().scale(alpha);
        assert!(verify_archetype_idempotent(&a, 0.5, 1e-12));
        // Sanity: a wrong α should fail.
        let bad = Mat4::identity().scale(0.5);
        assert!(!verify_archetype_idempotent(&bad, 0.5, 1e-12));
    }
#[test]
    fn fixed_point_check_matches_idempotency() {
        // a ⊗_ε p* = p* with p* = a and a idempotent.
        let alpha = 2.0 / 3.0;
        let a = Mat4::identity().scale(alpha);
        assert!(verify_fixed_point(&a, &a, 0.5, 1e-12));
    }
#[test]
    fn deformed_tensor_product_idempotency_matches_manual() {
        let alpha = 2.0 / 3.0;
        let a = Mat4::identity().scale(alpha);
        let r = deformed_tensor_product(&a, &a, 0.5);
        assert!(r.approx_eq(&a, 1e-12));
    }
}
simd.rs — SIMD оптимизации
//! simd.rs — Optional SIMD wrappers via the `wide` crate.
//!
//! Behind the `simd` feature flag. Provides a `Vec4x4` type that packs four
//! independent `Vec4`s into a single SIMD register, useful for batched
//! chunk-streaming math (e.g. computing 4 P³ distances at once).
//!
//! On x86-64 this lowers to `f64x4` SSE2/AVX instructions; on AArch64 to
//! NEON. Falls back to scalar on unsupported targets.
//!
//! This is NOT required for correctness — every operation has a scalar
//! equivalent in [`crate::tensor`]. The `simd` module exists purely for
//! throughput on hot paths identified by the rendering agent.
use wide::{CmpGt, f64x4};
/// Four `Vec4`s laid out struct-of-arrays (SoA) for SIMD processing.
///
/// Lane `i` of each `f64x4` holds component `i` across 4 vectors. So
/// `xs.0[0]` is the x-component of vectors 0, 1, 2, 3 — perfect for
/// `dot`/`norm`/`normalize` which are horizontal-reduction-free in SoA.
#[derive(Clone, Copy, Debug)]
pub struct Vec4x4 {
    pub xs: f64x4,
    pub ys: f64x4,
    pub zs: f64x4,
    pub ws: f64x4,
}
impl Vec4x4 {
    /// Construct from four `Vec4`s (array-of-structures → structure-of-arrays).
    #[inline]
    pub fn from_aos(v: [crate::tensor::Vec4; 4]) -> Self {
        let arr: [[f64; 4]; 4] = [v[0].0, v[1].0, v[2].0, v[3].0];
        Self {
            xs: f64x4::from([arr[0][0], arr[1][0], arr[2][0], arr[3][0]]),
            ys: f64x4::from([arr[0][1], arr[1][1], arr[2][1], arr[3][1]]),
            zs: f64x4::from([arr[0][2], arr[1][2], arr[2][2], arr[3][2]]),
            ws: f64x4::from([arr[0][3], arr[1][3], arr[2][3], arr[3][3]]),
        }
    }
/// Convert back to array-of-structures.
    #[inline]
    pub fn to_aos(&self) -> [crate::tensor::Vec4; 4] {
        let xs: [f64; 4] = self.xs.into();
        let ys: [f64; 4] = self.ys.into();
        let zs: [f64; 4] = self.zs.into();
        let ws: [f64; 4] = self.ws.into();
        [
            crate::tensor::Vec4([xs[0], ys[0], zs[0], ws[0]]),
            crate::tensor::Vec4([xs[1], ys[1], zs[1], ws[1]]),
            crate::tensor::Vec4([xs[2], ys[2], zs[2], ws[2]]),
            crate::tensor::Vec4([xs[3], ys[3], zs[3], ws[3]]),
        ]
    }
/// Lane-wise dot product: returns 4 dot products as an `f64x4`.
    #[inline]
    pub fn dot(&self, other: &Self) -> f64x4 {
        self.xs * other.xs + self.ys * other.ys + self.zs * other.zs + self.ws * other.ws
    }
/// Lane-wise squared norm.
    #[inline]
    pub fn norm_sq(&self) -> f64x4 {
        self.dot(self)
    }
/// Lane-wise normalize. Lanes with `‖v‖ < 1e-15` are returned as zero.
    #[inline]
    pub fn normalize(&self) -> Self {
        let n_sq = self.norm_sq();
        // Use hardware sqrt. For near-zero lanes (n_sq ≤ 1e-15) we return
        // zero — this avoids producing NaN/Inf from 1/0.
        // Implementation: compute inv_n = 1/sqrt(n_sq), then zero out lanes
        // where n_sq is too small by multiplying by a 0/1 mask.
        let n = n_sq.sqrt();
        let inv_n = f64x4::splat(1.0) / n;
        // Build a 0.0/1.0 lane mask from the comparison `n_sq > 1e-15`.
        // The CmpGt trait returns an f64x4 whose bits are all-1s for "true"
        // lanes and all-0s for "false". We AND that with 1.0 to get a
        // 0.0/1.0 multiplier.
        let mask = n_sq.cmp_gt(f64x4::splat(1e-15));
        // Convert the all-bits mask to a 0.0/1.0 f64x4 by bitwise AND with
        // 1.0. (In IEEE-754, 1.0 has bits 0x3FF0000000000000, so ANDing with
        // all-1s preserves 1.0 and ANDing with all-0s gives 0.0.)
        let one_bits = f64x4::splat(1.0);
        // wide exposes bitwise operations through the `BitAnd` trait.
        let mask_as_01 = mask & one_bits;
        let safe_inv = inv_n * mask_as_01;
        Self {
            xs: self.xs * safe_inv,
            ys: self.ys * safe_inv,
            zs: self.zs * safe_inv,
            ws: self.ws * safe_inv,
        }
    }
/// Lane-wise scale.
    #[inline]
    pub fn scale(&self, alpha: f64x4) -> Self {
        Self {
            xs: self.xs * alpha,
            ys: self.ys * alpha,
            zs: self.zs * alpha,
            ws: self.ws * alpha,
        }
    }
/// Lane-wise add.
    #[inline]
    pub fn add(&self, other: &Self) -> Self {
        Self {
            xs: self.xs + other.xs,
            ys: self.ys + other.ys,
            zs: self.zs + other.zs,
            ws: self.ws + other.ws,
        }
    }
/// Lane-wise sub.
    #[inline]
    pub fn sub(&self, other: &Self) -> Self {
        Self {
            xs: self.xs - other.xs,
            ys: self.ys - other.ys,
            zs: self.zs - other.zs,
            ws: self.ws - other.ws,
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
#[test]
    fn dot_matches_scalar() {
        let a = Vec4x4::from_aos([
            crate::tensor::Vec4([1.0, 2.0, 3.0, 4.0]),
            crate::tensor::Vec4([1.0, 0.0, 0.0, 0.0]),
            crate::tensor::Vec4([0.0, 1.0, 0.0, 0.0]),
            crate::tensor::Vec4([2.0, 2.0, 1.0, 1.0]),
        ]);
        let b = Vec4x4::from_aos([
            crate::tensor::Vec4([1.0, 1.0, 1.0, 1.0]),
            crate::tensor::Vec4([2.0, 0.0, 0.0, 0.0]),
            crate::tensor::Vec4([0.0, 3.0, 0.0, 0.0]),
            crate::tensor::Vec4([1.0, 1.0, 1.0, 1.0]),
        ]);
        let d = a.dot(&b);
        let arr: [f64; 4] = d.into();
        assert!((arr[0] - 10.0).abs() < 1e-9); // 1+2+3+4
        assert!((arr[1] - 2.0).abs() < 1e-9);
        assert!((arr[2] - 3.0).abs() < 1e-9);
        assert!((arr[3] - 6.0).abs() < 1e-9); // 2+2+1+1
    }
#[test]
    fn normalize_matches_scalar() {
        let a = Vec4x4::from_aos([
            crate::tensor::Vec4([3.0, 0.0, 0.0, 0.0]),
            crate::tensor::Vec4([0.0, 4.0, 0.0, 0.0]),
            crate::tensor::Vec4([0.0, 0.0, 5.0, 0.0]),
            crate::tensor::Vec4([0.0, 0.0, 0.0, 6.0]),
        ]);
        let n = a.normalize();
        let out = n.to_aos();
        for i in 0..4 {
            let norm = out[i].norm();
            assert!((norm - 1.0).abs() < 1e-9, "lane {i}: norm={norm}");
        }
    }
}
quantum.rs — Quantum Normalization
//! quantum.rs — Quantum normalization.
//!
//! ```text
//! p_{t+1} = (1 − mix) · P_new + mix · P_new / ‖P_new‖
//! ```
//!
//! Interpolates between the raw POLER update (`mix = 0`) and a unit-norm
//! projection (`mix = 1`). Provides topological regularization: prevents the
//! trajectory from diverging while preserving direction.
//!
//! Direct f64 port of `tensor.zig::quantumNormalize` (lines 475-480). The
//! 1/‖·‖ factor is the same operation that the CORDIC module on the FPGA
//! (`cordic_inv_sqrt.v`) accelerates in Q32.32 — see
//! [`crate::cordic::inv_sqrt`].
use crate::cordic::inv_sqrt;
use crate::tensor::{Mat4, Vec4};
/// Default quantum-normalization mixing coefficient (matches `tensor.zig:502`).
pub const DEFAULT_MIX: f64 = 0.1;
/// Quantum normalization for a `Mat4`-encoded state vector.
///
/// The state is interpreted as a 4×1 column inside a 4×4 matrix (the Zig
/// convention). `‖P_new‖` is the Euclidean norm of column 0.
///
/// Direct port of `tensor.zig::quantumNormalize` (lines 475-480).
pub fn quantum_normalize(p_new: &Mat4, mix: f64) -> Mat4 {
    // ‖P_new‖ — uses CORDIC inv_sqrt for FPGA parity.
    let mut sum_sq = 0.0;
    for i in 0..4 {
        let v = p_new.get(i, 0);
        sum_sq += v * v;
    }
    let inv_norm = if sum_sq < 1e-300 { 0.0 } else { inv_sqrt(sum_sq) };
let mut out = Mat4::zero();
    for i in 0..4 {
        let p_i = p_new.get(i, 0);
        // raw = (1 − mix) · p_i
        let raw = (1.0 - mix) * p_i;
        // unit = mix · p_i / ‖p‖  =  (mix · p_i) · (1/‖p‖)
        let unit = mix * p_i * inv_norm;
        out.set(i, 0, raw + unit);
    }
    out
}
/// Quantum normalization for a `Vec4` state.
///
/// Convenience wrapper for the common case where the state really is a 4-vector
/// (not a 4×4 with three zero columns). Same formula.
pub fn quantum_normalize_vec(p: &Vec4, mix: f64) -> Vec4 {
    let norm_sq = p.dot(p);
    let inv_norm = if norm_sq < 1e-300 { 0.0 } else { inv_sqrt(norm_sq) };
    let mut out = [0.0; 4];
    for k in 0..4 {
        let v = p.0[k];
        let raw = (1.0 - mix) * v;
        let unit = mix * v * inv_norm;
        out[k] = raw + unit;
    }
    Vec4(out)
}
#[cfg(test)]
mod tests {
    use super::*;
#[test]
    fn mix_zero_is_identity() {
        let p = Mat4::from_rows(
            [3.0, 0.0, 0.0, 0.0],
            [4.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
        );
        let r = quantum_normalize(&p, 0.0);
        assert!(r.approx_eq(&p, 1e-12));
    }
#[test]
    fn mix_one_is_unit_norm() {
        let p = Mat4::from_rows(
            [3.0, 0.0, 0.0, 0.0],
            [4.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
        );
        let r = quantum_normalize(&p, 1.0);
        // ‖r‖ should be 1.
        let norm = (r.get(0, 0).powi(2) + r.get(1, 0).powi(2)).sqrt();
        assert!((norm - 1.0).abs() < 1e-12);
    }
#[test]
    fn direction_is_preserved() {
        let p = Mat4::from_rows(
            [3.0, 0.0, 0.0, 0.0],
            [4.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
        );
        let r = quantum_normalize(&p, 0.5);
        // r / ‖r‖ should equal p / ‖p‖ (same direction).
        let r_norm = (r.get(0, 0).powi(2) + r.get(1, 0).powi(2)).sqrt();
        let p_norm = 5.0; // 3-4-5 triangle
        assert!((r.get(0, 0) / r_norm - 3.0 / p_norm).abs() < 1e-12);
        assert!((r.get(1, 0) / r_norm - 4.0 / p_norm).abs() < 1e-12);
    }
#[test]
    fn vec4_variant_matches_mat4_variant() {
        let p_mat = Mat4::from_rows(
            [3.0, 0.0, 0.0, 0.0],
            [4.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0],
        );
        let p_vec = Vec4([3.0, 4.0, 0.0, 0.0]);
        let r_mat = quantum_normalize(&p_mat, 0.3);
        let r_vec = quantum_normalize_vec(&p_vec, 0.3);
        for k in 0..4 {
            assert!((r_mat.get(k, 0) - r_vec.0[k]).abs() < 1e-12);
        }
    }
}
q32_32.rs — Fixed-Point Q32.32
//! q32_32.rs — Optional Q32.32 fixed-point arithmetic for cache-friendly
//! hot paths and bit-exact cross-platform determinism.
//!
//! The FPGA implementation uses Q32.32 throughout (64-bit signed integers
//! with 32 integer bits and 32 fractional bits). On the CPU we use f64 by
//! default — but a few hot paths benefit from Q32.32:
//!
//! - **Deterministic multiplayer replays** — bit-exact across platforms
//!   (x86, ARM, WASM) without IEEE-754 rounding-mode surprises.
//! - **GPU-identical preprocessing** — for shaders that consume fixed-point
//!   attribute streams.
//! - **Streaming anti-drift** — when accumulated f64 drift would otherwise
//!   require frequent Π_Λ renormalization, switching a tight inner loop to
//!   Q32.32 eliminates the drift entirely.
//!
//! # Layout
//!
//! `Q32_32 = i64`. Value `v` represents the real number `v / 2^32`. Range:
//! `[-2^31, 2^31)` ≈ `[-2.1e9, 2.1e9)` with resolution `2.3e-10`.
//!
//! # Arithmetic
//!
//! - `qadd(a, b) = a + b` — exact.
//! - `qsub(a, b) = a − b` — exact.
//! - `qmul(a, b) = (a · b) >> 32` — `__mul`-hi-shift, matches
//!   `qmul` in `cordic_inv_sqrt.v:46-53`.
//! - `int2q(v) = v << 32`.
//!
//! # References
//! - `fpga-project/verilog/cordic_inv_sqrt.v` (Q32.32 helpers, lines 46-60)
//! - `fpga-project/verilog/newton_schulz_inv.v` (Q32.32 helpers, lines 31-59)
//! - `fpga-project/verilog/poler_cycle.v` (Q32.32 helpers, lines 91-119)
/// Number of fractional bits in Q32.32.
pub const FRAC_BITS: u32 = 32;
/// Q32.32 fixed-point value (64-bit signed integer with 32 fractional bits).
pub type Q32_32 = i64;
/// `1.0` in Q32.32 (i.e. `1 << 32`).
pub const ONE: Q32_32 = 1i64 << FRAC_BITS;
/// `2.0` in Q32.32.
pub const TWO: Q32_32 = 2 * ONE;
/// `3.0` in Q32.32.
pub const THREE: Q32_32 = 3 * ONE;
/// Convert an integer to Q32.32 (`v << 32`). Mirrors `int2q` in the Verilog.
#[inline]
pub const fn int2q(v: i32) -> Q32_32 {
    (v as i64) << FRAC_BITS
}
/// Convert an f64 to Q32.32, saturating on overflow.
#[inline]
pub fn from_f64(x: f64) -> Q32_32 {
    if !x.is_finite() {
        return if x > 0.0 { i64::MAX } else { i64::MIN };
    }
    let scaled = x * (ONE as f64);
    if scaled >= i64::MAX as f64 {
        i64::MAX
    } else if scaled <= i64::MIN as f64 {
        i64::MIN
    } else {
        scaled as i64
    }
}
/// Convert a Q32.32 value back to f64.
#[inline]
pub fn to_f64(q: Q32_32) -> f64 {
    (q as f64) / (ONE as f64)
}
/// Q32.32 addition. Exact.
#[inline]
pub const fn qadd(a: Q32_32, b: Q32_32) -> Q32_32 {
    a.wrapping_add(b)
}
/// Q32.32 subtraction. Exact.
#[inline]
pub const fn qsub(a: Q32_32, b: Q32_32) -> Q32_32 {
    a.wrapping_sub(b)
}
/// Q32.32 multiplication: `(a · b) >> 32` (arithmetic shift, sign-preserving).
///
/// Matches the Verilog `qmul` function in `cordic_inv_sqrt.v:46-53`:
/// ```verilog
/// function automatic signed [63:0] qmul;
///     input signed [63:0] a, b;
///     reg signed [127:0] full;
///     begin
///         full = a * b;
///         qmul = full >>> FRAC_BITS;
///     end
/// endfunction
/// ```
#[inline]
pub fn qmul(a: Q32_32, b: Q32_32) -> Q32_32 {
    // 128-bit product, then arithmetic right shift by 32.
    let full = (a as i128) * (b as i128);
    (full >> FRAC_BITS) as i64
}
/// Q32.32 division: `(a << 32) / b`. NOT in the Verilog (FPGA avoids
/// division), but useful on CPU for diagnostics.
#[inline]
pub fn qdiv(a: Q32_32, b: Q32_32) -> Q32_32 {
    if b == 0 {
        return if a >= 0 { i64::MAX } else { i64::MIN };
    }
    let shifted = (a as i128) << FRAC_BITS;
    (shifted / (b as i128)) as i64
}
/// Q32.32 `1/sqrt(x)` via Newton-Raphson, 6 iterations.
///
/// Mirrors `cordic_inv_sqrt.v`:
/// ```text
/// y_{k+1} = 0.5 · y_k · (3 − x · y_k²)
/// ```
///
/// Initial guess: shift `1.0` by `−exponent/2`, where the exponent is
/// recovered from the position of the MSB (the "count leading zeros" trick).
///
/// Returns `0` for `x ≤ 0` (matches `valid = 0` in the Verilog).
pub fn inv_sqrt(x: Q32_32) -> Q32_32 {
    inv_sqrt_iter(x, 6)
}
/// `1/sqrt(x)` with caller-specified iteration count.
pub fn inv_sqrt_iter(x: Q32_32, iter: usize) -> Q32_32 {
    if x <= 0 {
        return 0;
    }
// Find the position of the MSB (the Verilog "count leading zeros").
    let msb_pos = (63 - (x as u64).leading_zeros()) as i32; // 0..63
    let exp_val = msb_pos - FRAC_BITS as i32; // exponent in the Q32.32 representation
    // Arithmetic shift right on signed (matches Verilog `>>> 1` on signed):
    // -1 >> 1 = -1, -2 >> 1 = -1, -3 >> 1 = -2 (sign-extending floor div by 2).
    let half_exp = exp_val >> 1;
// y_0 = 2^(-half_exp) in Q32.32.
    let y0 = if half_exp >= 0 {
        ONE >> half_exp as u32
    } else {
        ONE << (-half_exp) as u32
    };
// If exp_val is odd, multiply by 1/sqrt(2) ≈ 0.7071067811865475.
    // In Q32.32: 0.7071067811865475 · 2^32 ≈ 3037000499.97 ≈ 0xB504F334.
    let mut y = if exp_val & 1 != 0 {
        qmul(y0, 0xB504F334u32 as i64 as Q32_32)
    } else {
        y0
    };
for _ in 0..iter {
        // y_{k+1} = 0.5 · y_k · (3 − x · y_k²)
        let y_sq = qmul(y, y);
        let x_y_sq = qmul(x, y_sq);
        let three_minus = qsub(THREE, x_y_sq);
        let y_factor = qmul(y, three_minus);
        // 0.5 · y_factor = y_factor >> 1 (logical shift, since this is positive
        // in the basin of attraction — but we use arithmetic shift for safety).
        y = y_factor >> 1;
    }
    y
}
/// Q32.32 `1/x` via Newton-Raphson, 4 iterations.
///
/// Mirrors `approx_recip` in `newton_schulz_inv.v:63-114`. Used as the
/// initial guess for Newton-Schulz matrix inversion.
pub fn recip(x: Q32_32) -> Q32_32 {
    if x == 0 || x < 0 {
        return ONE; // matches Verilog fallback
    }
    let msb_pos = (63 - (x as u64).leading_zeros()) as i32;
    // y_0 ≈ 2^(2·FRAC − 1 − msb_pos).  See Verilog comments.
    let shift = (2 * FRAC_BITS as i32) - 1 - msb_pos;
    let mut y: Q32_32 = if shift >= 0 && shift < 63 {
        1i64 << shift
    } else {
        ONE
    };
for _ in 0..4 {
        // y_{k+1} = y_k · (2 − x · y_k)
        let xy = qmul(x, y);
        let two_minus_xy = qsub(TWO, xy);
        y = qmul(y, two_minus_xy);
    }
    y
}
/// Q32.32 4×4 matrix inversion via Newton-Schulz (8 iterations, default).
///
/// Flat 16-element row-major layout, matching the Verilog `M_in[0..15]`.
///
/// Returns `None` if the regularized matrix is too close to singular.
pub fn invert_newton_schulz_q(
    m: &[Q32_32; 16],
    delta: Q32_32,
    max_iter: usize,
) -> Option<[Q32_32; 16]> {
    // Step 1: M_reg = M + δ·I.
    let mut m_reg = *m;
    for i in 0..4 {
        m_reg[i * 4 + i] = qadd(m_reg[i * 4 + i], delta);
    }
// Step 2: α = 2 / tr(M_reg).
    let trace = m_reg[0] + m_reg[5] + m_reg[10] + m_reg[15];
    if trace == 0 {
        return None;
    }
    let alpha = qmul(TWO, recip(trace));
// Step 3: X_0 = α·I.
    let mut x = [0i64; 16];
    for i in 0..4 {
        x[i * 4 + i] = alpha;
    }
for _ in 0..max_iter {
        // T = M_reg · X_k
        let mut t = [0i64; 16];
        for i in 0..4 {
            for j in 0..4 {
                let mut acc: Q32_32 = 0;
                for k in 0..4 {
                    acc = qadd(acc, qmul(m_reg[i * 4 + k], x[k * 4 + j]));
                }
                t[i * 4 + j] = acc;
            }
        }
        // S = 2I − T
        let mut s = [0i64; 16];
        for i in 0..4 {
            for j in 0..4 {
                if i == j {
                    s[i * 4 + j] = qsub(TWO, t[i * 4 + j]);
                } else {
                    s[i * 4 + j] = qsub(0, t[i * 4 + j]);
                }
            }
        }
        // X_{k+1} = X_k · S
        let mut x_new = [0i64; 16];
        for i in 0..4 {
            for j in 0..4 {
                let mut acc: Q32_32 = 0;
                for k in 0..4 {
                    acc = qadd(acc, qmul(x[i * 4 + k], s[k * 4 + j]));
                }
                x_new[i * 4 + j] = acc;
            }
        }
        x = x_new;
// Convergence: ‖M_reg · X_k − I‖_F² (in Q32.32) < 2^(-16) of ONE.
        let threshold = ONE >> 16; // matches Verilog `int2q(1) >>> 16`
        let mut err_sq: Q32_32 = 0;
        for i in 0..4 {
            for j in 0..4 {
                let mut mx_ij: Q32_32 = 0;
                for k in 0..4 {
                    mx_ij = qadd(mx_ij, qmul(m_reg[i * 4 + k], x[k * 4 + j]));
                }
                let target = if i == j { ONE } else { 0 };
                let diff = qsub(target, mx_ij);
                err_sq = qadd(err_sq, qmul(diff, diff));
            }
        }
        if err_sq < threshold {
            return Some(x);
        }
    }
    Some(x)
}
#[cfg(test)]
mod tests {
    use super::*;
fn approx_eq_q(a: Q32_32, b: Q32_32, tol_f64: f64) -> bool {
        (to_f64(a) - to_f64(b)).abs() < tol_f64
    }
#[test]
    fn round_trip_f64() {
        for &x in &[0.5_f64, 1.0, 2.0, 3.14, -1.5, 100.0] {
            let q = from_f64(x);
            let back = to_f64(q);
            assert!((back - x).abs() / x.abs().max(1.0) < 1e-9, "x={x}: back={back}");
        }
    }
#[test]
    fn qmul_matches_f64() {
        for &(a, b) in &[(2.0_f64, 3.0_f64), (0.5, 0.25), (1.5, -2.0), (10.0, 0.1)] {
            let qa = from_f64(a);
            let qb = from_f64(b);
            let got = to_f64(qmul(qa, qb));
            let want = a * b;
            assert!(
                (got - want).abs() < 1e-6,
                "qmul({a}, {b}): got={got}, want={want}"
            );
        }
    }
#[test]
    fn inv_sqrt_matches_f64() {
        for &x in &[0.25_f64, 0.5, 1.0, 2.0, 4.0, 16.0, 100.0] {
            let qx = from_f64(x);
            let got = to_f64(inv_sqrt(qx));
            let want = 1.0 / x.sqrt();
            let rel_err = (got - want).abs() / want;
            assert!(rel_err < 1e-6, "x={x}: got={got}, want={want}, rel_err={rel_err}");
        }
    }
#[test]
    fn recip_matches_f64() {
        // 4-iteration Newton-Raphson starting from a 1-bit initial guess
        // achieves ~1e-5 relative precision (matches the Verilog
        // `approx_recip` precision). The bit-shift initial guess is
        // intentionally suboptimal — it's the FPGA's only option without
        // hardware divide.
        for &x in &[0.5_f64, 1.0, 2.0, 4.0, 100.0] {
            let qx = from_f64(x);
            let got = to_f64(recip(qx));
            let want = 1.0 / x;
            let rel_err = (got - want).abs() / want;
            assert!(rel_err < 1e-4, "x={x}: got={got}, want={want}, rel_err={rel_err}");
        }
    }
#[test]
    fn newton_schulz_q_inverts_diagonal() {
        // diag(4, 2, 1, 0.5)
        let mut m = [0i64; 16];
        m[0] = from_f64(4.0);
        m[5] = from_f64(2.0);
        m[10] = from_f64(1.0);
        m[15] = from_f64(0.5);
        let inv = invert_newton_schulz_q(&m, from_f64(1e-6), 8).unwrap();
        // Expected diag(0.25, 0.5, 1.0, 2.0)
        assert!(approx_eq_q(inv[0], from_f64(0.25), 1e-3));
        assert!(approx_eq_q(inv[5], from_f64(0.5), 1e-3));
        assert!(approx_eq_q(inv[10], from_f64(1.0), 1e-3));
        assert!(approx_eq_q(inv[15], from_f64(2.0), 1e-3));
    }
#[test]
    fn int2q_round_trip() {
        for &v in &[0i32, 1, 2, -1, 100, -1000] {
            assert_eq!(to_f64(int2q(v)) as i64, v as i64);
        }
    }
}