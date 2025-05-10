'use strict';
'require baseclass';
'require rpc';

var callSystemInfo = rpc.declare({ object: 'system', method: 'info' });

function progressbar(value, max, byte) {
	var vn = parseInt(value) || 0,
		mn = parseInt(max) || 100,
		fv = byte ? String.format('%1024.2mB', value) : value,
		fm = byte ? String.format('%1024.2mB', max) : max,
		pc = Math.floor((100 / mn) * vn);
	return E('div', { 'class': 'cbi-progressbar', 'title': '%s / %s (%d%%)'.format(fv, fm, pc) },
		E('div', { 'style': 'width:%.2f%%'.format(pc) }));
}

return baseclass.extend({
	title: _(''),
	load: function () {
		return L.resolveDefault(callSystemInfo(), {});
	},
	render: function (systeminfo) {
		var mem  = L.isObject(systeminfo.memory) ? systeminfo.memory : {};
		var table = E('table', { 'class': 'table' });

		if (mem.total && mem.free) {
			var ramUsed = mem.total - mem.free;
			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [_('Ram')]),
				E('td', { 'class': 'td left' }, [progressbar(ramUsed, mem.total, true)])
			]));
		}

		return table;
	}
});