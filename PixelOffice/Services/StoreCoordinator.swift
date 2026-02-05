import Foundation

/// 도메인 Store들이 공유 상태에 접근하기 위한 프로토콜
/// CompanyStore가 이를 구현하여 coordinator 역할을 수행
@MainActor
protocol StoreCoordinator: AnyObject {
    /// 회사 데이터 (모든 도메인 Store가 접근)
    var company: Company { get set }

    /// 직원 상태 중앙 저장소
    var employeeStatuses: [UUID: EmployeeStatus] { get set }

    /// 데이터 저장
    func saveCompany()

    /// UI 업데이트 트리거 (objectWillChange.send())
    func triggerObjectUpdate()
}
