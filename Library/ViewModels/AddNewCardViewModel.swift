import KsApi
import Prelude
import ReactiveSwift
import ReactiveExtensions
import Result
import Stripe

public protocol AddNewCardViewModelInputs {
  func cardholderNameChanged(_ cardholderName: String)
  func cardholderNameTextFieldReturn()
  func paymentCardChanged(cardNumber: String, expMonth: Int, expYear: Int, cvc: String)
  func paymentInfo(valid: Bool)
  func paymentCardTextFieldReturn()
  func saveButtonTapped()
  func stripeCreated(_ token: String?, stripeID: String?)
  func stripeError(_ error: Error?)
  func viewDidLoad()
}

public protocol AddNewCardViewModelOutputs {
  var activityIndicatorShouldShow: Signal<Bool, NoError> { get }
  var addNewCardFailure: Signal<String, NoError> { get }
  var addNewCardSuccess: Signal<String, NoError> { get }
  var notifyMessageBannerPresent: Signal<String, NoError> { get }
  var cardholderNameBecomeFirstResponder: Signal<Void, NoError> { get }
  var dismissKeyboard: Signal<Void, NoError> { get }
  var paymentDetails: Signal<(String, String, Int, Int, String), NoError> { get }
  var paymentDetailsBecomeFirstResponder: Signal<Void, NoError> { get }
  var saveButtonIsEnabled: Signal<Bool, NoError> { get }
  var setStripePublishableKey: Signal<String, NoError> { get }
}

public protocol AddNewCardViewModelType {
  var inputs: AddNewCardViewModelInputs { get }
  var outputs: AddNewCardViewModelOutputs { get }
}

public final class AddNewCardViewModel: AddNewCardViewModelType, AddNewCardViewModelInputs,
AddNewCardViewModelOutputs {

  public init() {
    let cardholderName = self.cardholderNameChangedProperty.signal
    let paymentDetails = self.paymentCardChangedProperty.signal.skipNil()

    self.cardholderNameBecomeFirstResponder = self.viewDidLoadProperty.signal
    self.paymentDetailsBecomeFirstResponder = self.cardholderNameTextFieldReturnProperty.signal

    self.saveButtonIsEnabled = Signal.combineLatest(
      cardholderName.map { !$0.isEmpty },
      self.paymentInfoIsValidProperty.signal
      ).map { cardholderName, validation in cardholderName && validation }

    let paymentInput = Signal.combineLatest(cardholderName, paymentDetails)
      .map { cardholderName, paymentInfo in
        (cardholderName, paymentInfo.0, paymentInfo.1, paymentInfo.2, paymentInfo.3) }

    let tryAddCardAction = Signal.merge(
      self.paymentCardTextFieldReturnProperty.signal,
      self.saveButtonTappedProperty.signal
    )
    self.paymentDetails = paymentInput
      .takeWhen(self.saveButtonTappedProperty.signal)

    self.dismissKeyboard = tryAddCardAction

    self.setStripePublishableKey = self.saveButtonIsEnabled
      .filter(isTrue)
      .map { _ in AppEnvironment.current.config?.stripePublishableKey }
      .skipNil()

    let addNewCardEvent = self.stripeTokenProperty.signal.skipNil()
      .map { CreatePaymentSourceInput(paymentType: PaymentType.creditCard, stripeToken: $0.0, stripeCardId: $0.1) }
      .flatMap {
        AppEnvironment.current.apiService.addNewCreditCard(input: $0)
          .ksr_delay(AppEnvironment.current.apiDelayInterval, on: AppEnvironment.current.scheduler)
          .materialize()
       }

    self.addNewCardSuccess = addNewCardEvent.values().ignoreValues()
      .map { _ in Strings.Got_it_your_changes_have_been_saved() }
    self.addNewCardFailure = self.stripeErrorProperty.signal.map { $0?.localizedDescription }.skipNil()

    self.notifyMessageBannerPresent = .empty

    self.activityIndicatorShouldShow = Signal.merge(
      tryAddCardAction.signal.mapConst(true),
      self.addNewCardSuccess.mapConst(false),
      self.addNewCardFailure.mapConst(false)
    )
  }

  private let cardholderNameChangedProperty = MutableProperty("")
  public func cardholderNameChanged(_ cardholderName: String) {
    self.cardholderNameChangedProperty.value = cardholderName
  }

  private let cardholderNameTextFieldReturnProperty = MutableProperty(())
  public func cardholderNameTextFieldReturn() {
    self.cardholderNameTextFieldReturnProperty.value = ()
  }

  private let paymentCardChangedProperty = MutableProperty<(String, Int, Int, String)?>(nil)
  public func paymentCardChanged(cardNumber: String, expMonth: Int, expYear: Int, cvc: String) {
    self.paymentCardChangedProperty.value = (cardNumber, expMonth, expYear, cvc)
  }

  private let paymentCardTextFieldReturnProperty = MutableProperty(())
  public func paymentCardTextFieldReturn() {
    self.paymentCardTextFieldReturnProperty.value = ()
  }

  private let paymentInfoIsValidProperty = MutableProperty(false)
  public func paymentInfo(valid: Bool) {
    self.paymentInfoIsValidProperty.value = valid
  }

  private let saveButtonTappedProperty = MutableProperty(())
  public func saveButtonTapped() {
    self.saveButtonTappedProperty.value = ()
  }

  private let stripeErrorProperty = MutableProperty(Error?.none)
  public func stripeError(_ error: Error?) {
    self.stripeErrorProperty.value = error
  }

  private let stripeTokenProperty = MutableProperty<(String, String)?>(nil)
  public func stripeCreated(_ token: String?, stripeID: String?) {
    if let token = token, let stripeID = stripeID {
      self.stripeTokenProperty.value = (token, stripeID )
    }
  }

  private let viewDidLoadProperty = MutableProperty(())
  public func viewDidLoad() {
    self.viewDidLoadProperty.value = ()
  }

  public let activityIndicatorShouldShow: Signal<Bool, NoError>
  public let addNewCardFailure: Signal<String, NoError>
  public let addNewCardSuccess: Signal<String, NoError>
  public let cardholderNameBecomeFirstResponder: Signal<Void, NoError>
  public let dismissKeyboard: Signal<Void, NoError>
  public let notifyMessageBannerPresent: Signal<String, NoError>
  public let paymentDetails: Signal<(String, String, Int, Int, String), NoError>
  public let paymentDetailsBecomeFirstResponder: Signal<Void, NoError>
  public let saveButtonIsEnabled: Signal<Bool, NoError>
  public let setStripePublishableKey: Signal<String, NoError>

  public var inputs: AddNewCardViewModelInputs { return self }
  public var outputs: AddNewCardViewModelOutputs { return self }
}
