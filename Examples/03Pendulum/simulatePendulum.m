% Copyright 2019 Jonas Koenemann, Moritz Diehl, University of Freiburg
% Copyright 2015-2018 Jonas Koennemanm, Giovanni Licitra
% Redistribution is permitted under the 3-Clause BSD License terms. Please
% ensure the above copyright notice is visible in any derived work.
%
function xVec = simulatePendulum

% Create system and simulator
s = PendulumSystem;
system = OclSystem(s.varsfun, s.eqfun, s.icfun, 'cbsetupfun', s.simcallbacksetup, 'cbfun', s.simcallback);
simulator = Simulator(system);

states = simulator.getStates();
states.p.set([0,1]);
states.v.set([-0.5,-1]);

p = simulator.getParameters();
p.m.set(1);
p.l.set(1);

times = 0:0.1:4;

% simulate without control inputs
%simulator.simulate(states,times,p);

% simulate again using a given series of control inputs
controlsSeries = simulator.getControlsVec(length(times)-1);
controlsSeries.F.set(10);

[xVec,~,~] = simulator.simulate(states,times,controlsSeries,p);

end



function pathcosts(ch,~,~,controls,~,~,~)
  F  = controls.F;
  ch.add( 1e-3 * F^2 );
end

