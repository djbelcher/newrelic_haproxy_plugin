module PluginAgent
  class DeltaCounter
    def process(val)
        ret = nil

        if val && @last_value
            val = val.to_i
            ret = val - @last_value
        end

        @last_value = val

        # This next line is to avoid large negative
        # spikes during epoch reset events.
        return nil if ret.nil? || ret < 0
        ret
    end
  end
end
