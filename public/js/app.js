// Ai La Carte - Internal Customer Support JavaScript

document.addEventListener('DOMContentLoaded', function() {
  // Initialize tooltips
  var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
  tooltipTriggerList.map(function (tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl);
  });

  // Confirm delete actions
  document.querySelectorAll('form[data-confirm]').forEach(function(form) {
    form.addEventListener('submit', function(e) {
      if (!confirm(this.dataset.confirm)) {
        e.preventDefault();
      }
    });
  });

  // Image preview modal
  document.querySelectorAll('.photo-preview, .card-img-top').forEach(function(img) {
    img.style.cursor = 'pointer';
    img.addEventListener('click', function() {
      var modal = document.createElement('div');
      modal.className = 'modal fade';
      modal.innerHTML = `
        <div class="modal-dialog modal-lg modal-dialog-centered">
          <div class="modal-content">
            <div class="modal-body p-0">
              <img src="${this.src}" class="w-100" alt="Preview">
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
            </div>
          </div>
        </div>
      `;
      document.body.appendChild(modal);
      var bsModal = new bootstrap.Modal(modal);
      bsModal.show();
      modal.addEventListener('hidden.bs.modal', function() {
        modal.remove();
      });
    });
  });

  // Auto-hide alerts after 5 seconds
  document.querySelectorAll('.alert:not(.alert-info)').forEach(function(alert) {
    setTimeout(function() {
      var bsAlert = bootstrap.Alert.getOrCreateInstance(alert);
      if (bsAlert) {
        bsAlert.close();
      }
    }, 5000);
  });

  // Form loading state
  document.querySelectorAll('form').forEach(function(form) {
    form.addEventListener('submit', function() {
      var submitBtn = this.querySelector('button[type="submit"]');
      if (submitBtn) {
        submitBtn.disabled = true;
        var originalText = submitBtn.innerHTML;
        submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2" role="status"></span>Loading...';

        // Re-enable after 10 seconds (fallback)
        setTimeout(function() {
          submitBtn.disabled = false;
          submitBtn.innerHTML = originalText;
        }, 10000);
      }
    });
  });

  // Restaurant search with debounce
  var searchInput = document.querySelector('input[name="q"]');
  if (searchInput && searchInput.closest('form').action.includes('restaurants')) {
    var debounceTimer;
    searchInput.addEventListener('input', function() {
      clearTimeout(debounceTimer);
      var form = this.closest('form');
      debounceTimer = setTimeout(function() {
        // Optional: auto-submit on type
        // form.submit();
      }, 500);
    });
  }

  // Highlight current nav item
  var currentPath = window.location.pathname;
  document.querySelectorAll('.navbar-nav .nav-link').forEach(function(link) {
    if (link.getAttribute('href') === currentPath) {
      link.classList.add('active');
    }
  });

  // Session storage for preserving tab state
  var tabLinks = document.querySelectorAll('[data-bs-toggle="tab"]');
  tabLinks.forEach(function(tabLink) {
    tabLink.addEventListener('shown.bs.tab', function(e) {
      sessionStorage.setItem('activeTab', e.target.id);
    });
  });

  var activeTab = sessionStorage.getItem('activeTab');
  if (activeTab) {
    var tab = document.getElementById(activeTab);
    if (tab) {
      new bootstrap.Tab(tab).show();
    }
  }
});

// Utility function for AJAX requests
function fetchJSON(url, options = {}) {
  return fetch(url, {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers
    },
    ...options
  }).then(response => {
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  });
}
