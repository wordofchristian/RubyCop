class Player
  attr_reader :warrior

  def play_turn(warrior)
    @warrior = warrior
    take_action
  end

  def method_missing(m, *args, &block)
    warrior.safe_send(m, *args, &block)
  end

  private

  def take_action
    warrior.listen
    return walk!(direction_of_stairs) if listen.none?
    return save_ticking_captive if ticking
    return rest! if hurt? && safe?
    return bind!(feel_enemy) if surrounding_enemy_count > 1
    return attack!(feel_enemy) if feel_enemy
    return rescue!(feel_captive) if feel_captive
    return walk!(move_around) if feel.stairs? && enemy_count > 0
    return walk!(direction_of(listen.first)) if listen.any?
    return walk!(direction_of_stairs)
  end

  def save_ticking_captive
    return rescue!(feel_ticking) if feel_ticking
    return rest! if prudent?
    return walk!(ticking) if feel(ticking).empty?
    return walk!(move_around) if move_around
    return bind!(feel_enemy) if surrounding_enemy_count > 1
    return detonate! if look[0].enemy? && look[1].enemy? && health > 5
    return attack!(feel_enemy) if feel_enemy
  end

  def move_around
    [:left, :right, :forward].select { |d| feel(d).empty? }.first
  end

  def prudent?
    safe? && enemy_count > 0 &&
      (
        (enemy_count < 5 && health < 7) ||
        (health < 10)
    )
  end

  def surrounding_enemy_count
    directions.select { |d| feel(d).enemy? }.size
  end

  def hurt?
    health < 20
  end

  def safe?
    !feel_enemy
  end

  def ticking
    captive = listen.select(&:ticking?).first
    return if !captive
    direction_of(captive)
  end

  def enemy_count
    listen.select { |u| u.enemy? }.size
  end

  def feel_captive
    directions.select { |d| feel(d).captive? }.first
  end

  def feel_enemy
    directions.select { |d| feel(d).enemy? }.first
  end

  def feel_ticking
    directions.select { |d| feel(d).captive? && feel(d).ticking? }.first
  end

  def directions
    [:left, :right, :forward, :backward]
  end
end
