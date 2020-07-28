require 'core/operation'
require 'mailers/contracts/state_change_notification'
require 'app/contracts/validations/update_state'
require 'app/shared/constants'
require_relative '../state_machine'

module App::Contracts
  module Operations
    #
    # NOTE: expects 'contract' option to be passed on call
    #
    class UpdateState < Core::Operation
      include App::Import[
        contracts:        'models.contract',
        countries_config: 'countries.config',
        t:                'i18n.t'
      ]

      # Configuration
      #--------------------------------------------------------------------------
      transaction true

      schema do
        required(:contract).schema(Validations::UpdateState)
      end

      # Execution
      #--------------------------------------------------------------------------
      step    Validate()
      step    :check_delivery_stop_at!
      step    :check_transition!
      failure Error('errors.common.state_transition_not_allowed')
      success :update_contract_state!
      success :update_delivery_stop_at!

      # Logic
      #--------------------------------------------------------------------------
      def check_delivery_stop_at!(opts, output:, contract:, **)
        del_stop_at = output[:contract][:delivery_stop_at]
        return true if !del_stop_at || (contract.start_at..contract.end_at).cover?(del_stop_at)

        message = t.('errors.contracts.operations.update_state.delivery_stop_at',
          start: format_date(contract.start_at),
          end: format_date(contract.end_at),
          delivery_stop_at: format_date(del_stop_at)
        )

        opts['result.errors'] = { message: message }
        false
      end

      def check_transition!(_opts, output:, contract:, **)
        StateMachine.new(contract).can_transition_to?(output[:contract][:state])
      end

      def update_contract_state!(_opts, output:, contract:, **)
        StateMachine.new(contract).transition_to(output[:contract][:state])
      end

      def update_delivery_stop_at!(_opts, output:, contract:, **)
        delivery_stop_at = output[:contract][:delivery_stop_at]
        return if delivery_stop_at.nil?

        contracts.update(contract.id, delivery_stop_at: delivery_stop_at)
      end

      private

      def format_date(date)
        date = Date.parse(date) if date.is_a?(String)
        date.strftime(App::Shared::Constants::DATE_FORMAT)
      end
    end
  end
end
