// 하네스 생성 — 시드 헬퍼 (custom: 1회 생성, 앱에 맞게 채우세요).
//
// 이 함수는 page.addInitScript로 브라우저 컨텍스트에 주입되어 앱 부팅 전에 실행된다.
// 가장 견고한 시드 방법은 앱의 영속 저장소(localStorage 등)에 직접 봉투를 주입하는 것이다.
//
// 예시 (Zustand persist 등 — 앱 구조에 맞게 수정):
//   export function seed(payload: { key: string; value: unknown }) {
//     window.localStorage.setItem(payload.key, JSON.stringify(payload.value));
//   }
// 주의: 직렬화 형태(DTO 배열 + version 필드 등)와 키 이름은 앱의 persist 설정과 정확히 일치해야 한다.
export function seed(_payload: unknown): void {
  // (앱별) 위 예시를 참고해 시드 로직을 구현하세요. 시드가 불필요하면 사용하지 않아도 됩니다.
}
