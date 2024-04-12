// jshint multistr: true
// jshint esversion: 6

var audit_url;
var ajax_url;

function getURLForType(type, event_data) {
  switch (type) {
    case 'comment_create':
    case 'comment_update':
      if (event_data.job_id !== undefined) {
        return '/tests/' + event_data.job_id + '#comments';
      } else if (event_data.group_id !== undefined) {
        return '/group_overview/' + event_data.group_id + '#comments';
      } else if (event_data.parent_group_id !== undefined) {
        return '/parent_group_overview/' + event_data.parent_group_id + '#comments';
      }
      break;
    case 'jobtemplate_create':
      if (event_data.job_group_id) {
        return '/admin/job_templates/' + event_data.job_group_id;
      }
      break;
    case 'job_create':
    case 'job_update_result':
    case 'job_done':
    case 'job_restart':
      return '/tests/' + event_data.id;
    case 'jobgroup_create':
      if (event_data.id) {
        return '/group_overview/' + event_data.id;
      }
      break;
    case 'iso_create':
      return '/admin/productlog?id=' + event_data.scheduled_product_id;
    case 'table_create':
      if (event_data.id) {
        switch (event_data.table) {
          case 'Machines':
            return '/admin/machines?q=' + event_data.id;
          case 'Products':
            return '/admin/products?q=' + event_data.id;
          case 'TestSuites':
            return '/admin/test_suites?q=' + event_data.id;
        }
      }
      break;
    case 'worker_register':
      return urlWithBase('/admin/workers/' + event_data.id);
  }
}

function undoComments(undoButton) {
  const ids = undoButton.dataset.ids.split(',');
  if (!window.confirm(`Do you really want to delete the ${ids.length} comment(s)?`)) {
    return;
  }
  undoButton.style.display = 'none';
  $.ajax({
    url: urlWithBase('/api/v1/comments'),
    method: 'DELETE',
    data: ids.map(id => `id=${id}`).join('&'),
    success: () => addFlash('info', 'The coments have been deleted.'),
    error: (jqXHR, textStatus, errorThrown) => {
      undoButton.style.display = 'inline';
      addFlash('danger', 'The comments could not be deleted: ' + getXhrError(jqXHR, textStatus, errorThrown));
    }
  });
}

function getElementForEventType(type, eventData) {
  if (type !== 'comments_create') {
    return '';
  }
  const ids = (eventData?.created || [])
    .map(data => parseInt(data?.id))
    .filter(Number.isInteger)
    .join(',');
  return `<br><button class="btn btn-danger undo-event" style="float: right" data-ids="${ids}" onclick="undoComments(this)">Undo</button>`;
}

function loadAuditLogTable() {
  $('#audit_log_table').DataTable({
    lengthMenu: [20, 40, 100],
    processing: true,
    serverSide: true,
    search: {search: searchquery},
    ajax: {url: ajax_url, type: 'GET', dataType: 'json'},
    columns: [
      {data: 'id'},
      {data: 'event_time'},
      {data: 'user'},
      {data: 'connection'},
      {data: 'event'},
      {data: 'event_data'}
    ],
    order: [[0, 'desc']],
    columnDefs: [
      {targets: 0, visible: false},
      {
        targets: 1,
        render: function (data, type, row) {
          if (type === 'display')
            // I want to have a link to events for cases when one wants to share interesting event
            return (
              '<a href="' +
              audit_url +
              '?eventid=' +
              row.id +
              '" title=' +
              data +
              '>' +
              jQuery.timeago(data + ' UTC') +
              '</a>'
            );
          else return data;
        }
      },
      {targets: 3, visible: false},
      {
        targets: 4,
        render: function (data, type, row) {
          if (type === 'display') {
            // Look for an id, and if we have one match it with an event type
            try {
              var url = urlWithBase(getURLForType(row.event, JSON.parse(row.event_data)));
              if (url) {
                return '<a class="audit_event_details" href="' + url + '">' + htmlEscape(data) + '</a>';
              }
            } catch (e) {
              // Intentionally ignore all errors
            }
          }
          return data;
        }
      },
      {
        targets: 5,
        width: '70%',
        render: function (data, type, row) {
          if (type === 'display' && data) {
            let parsedData;
            let typeSpecificElement = '';
            try {
              const eventData = JSON.parse(data);
              parsedData = JSON.stringify(eventData, null, 2);
              typeSpecificElement = getElementForEventType(row.event, eventData);
            } catch (e) {
              parsedData = data;
            }
            const escapedData = htmlEscape(parsedData);
            return `${typeSpecificElement}<span class="audit_event_data" title="${escapedData}">${escapedData}</span>`;
          } else {
            return data;
          }
        }
      }
    ]
  });
}

var scheduledProductsTable;

function dataForLink(link) {
  const rowData = scheduledProductsTable.row(link.parentElement?.parentElement).data();
  if (rowData === undefined) {
    console.error('unable to find row data for action link');
  }
  return rowData;
}

function showScheduledProductModalDialog(title, body) {
  const modalDialog = $('#scheduled-product-modal');
  modalDialog.find('.modal-title').text(title);
  modalDialog.find('.modal-body').empty().append(body);
  modalDialog.modal();
}

function renderScheduledProductSettings(settings) {
  const table = $('<table/>').addClass('table table-striped settings-table');
  for (const [key, value] of Object.entries(settings || {})) {
    table.append(
      $('<tr/>')
        .append($('<td/>').text(key))
        .append($('<td/>').append(renderHttpUrlAsLink(value)))
    );
  }
  return table;
}

function showScheduledProductSettings(link) {
  const rowData = dataForLink(link);
  if (rowData !== undefined) {
    showScheduledProductModalDialog('Scheduled product settings', renderScheduledProductSettings(rowData.settings));
  }
}

function renderScheduledProductResults(results) {
  let element;
  if (results) {
    element = $('<pre></pre>');
    element.text(JSON.stringify(results, undefined, 4));
  } else {
    element = $('<p></p>');
    element.text('No results available.');
  }
  return element;
}

function showScheduledProductResults(link) {
  const rowData = dataForLink(link);
  if (rowData !== undefined) {
    showScheduledProductModalDialog('Scheduled product results', renderScheduledProductResults(rowData.results));
  }
}

function rescheduleProductForActionLink(link) {
  const id = dataForLink(link)?.id;
  if (id && window.confirm('Do you really want to reschedule all jobs for the product ' + id + '?')) {
    rescheduleProduct(scheduledProductsTable.rescheduleUrlTemplate.replace('XXXXX', id));
  }
}

function rescheduleProduct(url) {
  $.post({
    url: url,
    success: (data, textStatus, jqXHR) => {
      const id = jqXHR.responseJSON?.scheduled_product_id;
      const msg =
        typeof id === 'number'
          ? 'The product has been re-triggered as <a href="/admin/productlog?id=' + id + '">' + id + '</a>.'
          : 'Re-scheduling the product has been triggered.';
      addFlash('info', msg);
    },
    error: (jqXHR, textStatus, errorThrown) => {
      addFlash('danger', 'Unable to trigger re-scheduling: ' + getXhrError(jqXHR, textStatus, errorThrown));
    }
  });
}

function showSettingsAndResults(rowData) {
  const scheduledProductsDiv = $('#scheduled-products');
  scheduledProductsDiv.append($('<h3>Settings</h3>'));
  scheduledProductsDiv.append(renderScheduledProductSettings(rowData.settings));
  scheduledProductsDiv.append($('<h3>Results</h3>'));
  scheduledProductsDiv.append(renderScheduledProductResults(rowData.results));
}

function loadProductLogTable(dataTableUrl, rescheduleUrlTemplate, showActions) {
  const params = new URLSearchParams(document.location.search.substring(1));
  const id = params.get('id');
  let settingsAndResultsShown = false;
  if (id) {
    dataTableUrl += '?id=' + encodeURIComponent(id);
    $('#scheduled-products h2').text('Scheduled product ' + id);
  }

  scheduledProductsTable = $('#product_log_table').DataTable({
    lengthMenu: [10, 25, 50],
    processing: true,
    serverSide: true,
    order: [[1, 'desc']],
    ajax: {
      url: dataTableUrl,
      type: 'GET',
      dataType: 'json',
      dataSrc: function (json) {
        const data = json.data;
        if (id && !settingsAndResultsShown) {
          showSettingsAndResults(data[0]);
          settingsAndResultsShown = true;
        }
        return data;
      }
    },
    columns: [
      {data: 'id'},
      {data: 't_created'},
      {data: 'user_name'},
      {data: 'status'},
      {data: 'distri'},
      {data: 'version'},
      {data: 'flavor'},
      {data: 'arch'},
      {data: 'build'},
      {data: 'iso'},
      {data: 'id'}
    ],
    columnDefs: [
      {
        targets: 0,
        visible: !id,
        render: function (data, type, row) {
          return type === 'display' ? '<a href="?id=' + encodeURIComponent(data) + '">' + data + '</a>' : data;
        }
      },
      {
        targets: 1,
        render: function (data, type, row) {
          return type === 'display' ? jQuery.timeago(data + 'Z') : data;
        }
      },
      {targets: 2, orderable: false},
      {
        targets: 10,
        orderable: false,
        render: function (data, type, row) {
          let html = '';
          if (!id) {
            html +=
              '<a href="#" onclick="showScheduledProductSettings(this); return true;">\
                                 <i class="action fa fa-search-plus" title="Show settings"></i></a>\
                                 <a href="#" onclick="showScheduledProductResults(this); return true;">\
                                 <i class="action fa fa-file" title="Show results"></i></a>';
          }
          if (showActions) {
            html +=
              '<a href="#" onclick="rescheduleProductForActionLink(this); return true;">\
                                 <i class="action fa fa-undo" title="Reschedule product tests"></i></a>';
          }
          return html;
        }
      }
    ]
  });

  scheduledProductsTable.rescheduleUrlTemplate = rescheduleUrlTemplate;

  // remove unneccassary elements when showing only one particular product
  if (id) {
    const wrapper = document.getElementById('product_log_table_wrapper');
    wrapper.removeChild(wrapper.firstChild);
    wrapper.removeChild(wrapper.lastChild);
  }
}
