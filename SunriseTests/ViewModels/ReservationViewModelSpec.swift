//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import ObjectMapper
import Result
@testable import Sunrise

class ReservationViewModelSpec: QuickSpec {

    static var order: Order = {
        let path = Bundle.currentTestBundle!.path(forResource: "reservation", ofType: "json")!
        let reservationJSON = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
        return Mapper<Order>().map(JSONString: reservationJSON as String)!
    }()
    
    override func spec() {
        describe("ReservationViewModelSpec") {
            var reservationViewModel: ReservationViewModel!
            
            beforeEach {
                reservationViewModel = ReservationViewModel(order: ReservationViewModelSpec.order)
            }
            
            it("has the proper product name") {
                expect(reservationViewModel.productName).to(equal("Walk Jacket \"Angie\""))
            }
            
            it("has the proper size") {
                expect(reservationViewModel.size).to(equal("M"))
            }

            it("has the proper price") {
                expect(reservationViewModel.price).to(equal("€269.10"))
            }

            it("has the proper channel / store name") {
                expect(reservationViewModel.storeName).to(equal("SUNRISE Store Berlin"))
            }

            it("has the proper street and number information") {
                expect(reservationViewModel.streetAndNumberInfo).to(equal("Unter den Linden 21"))
            }

            it("has the proper zip and city information") {
                expect(reservationViewModel.zipAndCityInfo).to(equal("10117, Berlin"))
            }

            it("has the proper opening hours line 1") {
                expect(reservationViewModel.openLine1Info).to(equal("Mo-Fr. 10:00AM - 8:00PM\nSa. 9:00AM - 6:00PM"))
            }

            it("has the proper product image URL") {
                expect(reservationViewModel.productImageUrl).to(equal("https://783878e5b17d95666954-b225316742fac565f0f82dc921727a90.ssl.cf3.rackcdn.com/FrlTrentini_Jacke_An-7XaeZC91.jpg"))
            }
            
        }
    }
}
